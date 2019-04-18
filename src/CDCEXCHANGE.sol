pragma solidity ^0.4.25;

import "ds-math/math.sol";
import "ds-auth/auth.sol";
import "ds-token/token.sol";
import "ds-stop/stop.sol";
import "ds-note/note.sol";


/**
 * @title CDC
 * @dev CDC EXCHANGE contract.
 */
contract CDCEXCHANGEEvents {
    event LogBuyToken(
        address owner,
        address sender,
        uint ethValue,
        uint cdcValue,
        uint rate
    );
    event LogBuyTokenWithFee(
        address owner,
        address sender,
        uint ethValue,
        uint cdcValue,
        uint rate,
        uint fee
    );
}

contract CDCEXCHANGE is DSAuth, DSStop, DSMath, CDCEXCHANGEEvents {
    ERC20 public cdc;                       //CDC token contract
    ERC20 public dpt;                       //DPT token contract
    uint public rate;                       //price of 1 CDC token. 18 digit precision
    // TODO: mutable?
    uint public constant fee = 0.015 ether; //fee on buy CDC via dApp

    /**
    * @dev Constructor
    */
    constructor(address cdc_, address dpt_, uint rate_) public {
        cdc = ERC20(cdc_);
        dpt = ERC20(dpt_);
        rate = rate_;
    }

    /**
    * @dev Fallback function is used to buy tokens.
    */
    function () external payable {
        buyTokens();
    }

    /**
    * @dev Тoken purchase function.
    */
    function buyTokens() public payable stoppable {
        require(msg.value != 0, "Invalid amount");

        uint tokens;
        tokens = wdiv(msg.value, rate);

        address(owner).transfer(msg.value);
        cdc.transferFrom(owner, msg.sender, tokens);
        emit LogBuyToken(owner, msg.sender, msg.value, tokens, rate);
    }

    /**
    * @dev Approve fee charge.
    */
    function approveFee(uint amount) public {
        dpt.approve(recipient, amount)
    }

    /**
    * @dev Тoken purchase with DPT fee function.
    */
    function buyTokensWithFee() public payable stoppable {
        require(msg.value != 0, "Invalid amount");

        uint tokens;
        tokens = wdiv(msg.value, rate);

        address(owner).transfer(msg.value);
        dpt.transferFrom(msg.sender, owner, fee);
        cdc.transferFrom(owner, msg.sender, tokens);
        emit LogBuyTokenWithFee(owner, msg.sender, msg.value, tokens, rate, fee);
    }

    /**
    * @dev Set exchange rate CDC/ETH value.
    */
    function setRate(uint rate_) public auth note {
        require(rate_ > 0, "Invalid amount");
        rate = rate_;
    }
}
