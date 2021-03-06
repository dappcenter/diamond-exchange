pragma solidity ^0.5.11;

import "ds-test/test.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "ds-guard/guard.sol";
import "cdc-token/Cdc.sol";
import "dpass/Dpass.sol";
import "./SimpleAssetManagement.sol";
import "./Wallet.sol";
import "./Dcdc.sol";

contract SimpleAssetManagementTest is DSTest, DSMath {
    event LogUintIpartUintFpart(bytes32 key, uint val, uint val1);
    event LogTest(uint256 what);
    event LogTest(bool what);
    event LogTest(address what);
    event LogTest(bytes32 what);

    uint public constant SUPPLY = (10 ** 10) * (10 ** 18);
    uint public constant INITIAL_BALANCE = 1000 ether;

    address payable public user;                            // TrustedSASMTester()
    address payable public custodian;                       // TrustedSASMTester()
    address payable public custodian1;                      // TrustedSASMTester()
    address payable public custodian2;                      // TrustedSASMTester()
    address payable public exchange;                        // TrustedSASMTester()

    address public dpt;                                     // DSToken()
    address public dai;                                     // DSToken()
    address public eth;                                     // DSToken()
    address public eng;                                     // DSToken()

    address public cdc;                                     // DSToken()
    address public cdc1;                                    // DSToken()
    address public cdc2;                                    // DSToken()

    address public dcdc;                                    // Dcdc()
    address public dcdc1;                                   // Dcdc()
    address public dcdc2;                                   // Dcdc()

    address public dpass;                                   // Dpass()
    address public dpass1;                                  // Dpass)
    address public dpass2;                                  // Dpass(()
    DSGuard public guard;
    bytes32 constant public ANY = bytes32(uint(-1));

    mapping(address => address) public feed;                // TestFeedLike()
    mapping(address => uint) public usdRate;                // TestFeedLike()

    mapping(address => uint) public decimals;               // decimal precision of token
    mapping(address => uint) dust;
    mapping(address => bool) dustSet;
    mapping(address => uint) cap;                           // custodian max collateral capacity

    SimpleAssetManagement public asm;                       // SimpleAssetManagement()
    bool showActualExpected;
    uint price1;
    uint overCollRemoveRatio;

    function setUp() public {
        _createActors();
        _createTokens();
        _setDust();
        _setGuardPermissions();
        _mintInitialSupply();
        _setDecimals();
        _setRates();
        _setFeeds();
        _setCustodianCap();
        _configAsm();
    }

    function testSetConfigRateAsm() public {
        asm.setConfig("rate", b(cdc), b(uint(10)), "diamonds");
        assertEq(asm.getRate(cdc), 10);
    }

    function testSetConfigTotalPaidCustVAsm() public {
        uint totalPaidCustV_ = 10 ether;                                                    // custodian was paid 10 ether total
        asm.setConfig("totalPaidCustV", b(custodian), b(totalPaidCustV_), "diamonds");
        assertEq(asm.totalPaidCustV(custodian), totalPaidCustV_);
    }

    function testFailSetConfigTotalPaidCustVAsm() public {
        uint totalPaidCustV_ = 10 ether;                                                    // custodian was paid 10 ether total
        asm.setConfig("totalPaidCustV", b(custodian), b(totalPaidCustV_), "diamonds");
        asm.setConfig("totalPaidCustV", b(custodian), b(totalPaidCustV_), "diamonds");      // this one fails, because we can only set it at first config time
    }

    function testFailSetConfigTotalPaidCustVNoCustodianAsm() public {
        uint totalPaidCustV_ = 10 ether;                                                    // custodian was paid 10 ether total
        asm.setConfig("totalPaidCustV", b(user), b(totalPaidCustV_), "diamonds");
    }

    function testSetRateAsm() public {
        asm.setRate(cdc, 12.1232312345 ether );
        assertEq(asm.getRate(cdc), 12.1232312345 ether);
    }
    function testSetPriceFeedAsm() public {
        asm.setConfig("priceFeed", b(cdc), b(address(0xe)), "diamonds");
        assertEq(asm.priceFeed(cdc), address(0xe));
    }

    function testSetDpassAsm() public {
        asm.setConfig("dpasses", b(address(0xefecd)), b(true), "diamonds");
        assertTrue(asm.dpasses(address(0xefecd)));
        assertTrue(asm.dpasses(dpass));
        assertTrue(asm.dpasses(dpass1));
        assertTrue(asm.dpasses(dpass2));
        assertTrue(!asm.dpasses(cdc));
        assertTrue(!asm.dpasses(cdc1));
        assertTrue(!asm.dpasses(cdc2));
        assertTrue(!asm.dpasses(dcdc));
        assertTrue(!asm.dpasses(dcdc1));
        assertTrue(!asm.dpasses(dcdc2));
        assertTrue(!asm.dpasses(dpt));
        assertTrue(!asm.dpasses(dai));
        assertTrue(!asm.dpasses(eth));
        assertTrue(!asm.dpasses(eng));
        assertTrue(!asm.dpasses(user));
        assertTrue(!asm.dpasses(custodian));
        assertTrue(!asm.dpasses(custodian1));
        assertTrue(!asm.dpasses(custodian2));
    }

    function testSetCdcAsm() public {
        address newToken = address(new DSToken("NEWTOKEN"));
        asm.setConfig("decimals", b(address(newToken)), b(uint(18)), "diamonds");
        asm.setConfig("priceFeed", b(address(newToken)), b(feed[cdc]), "diamonds");
        asm.setConfig("cdcs", b(address(newToken)), b(true), "diamonds");
        assertTrue(asm.cdcs(address(newToken)));
        assertTrue(!asm.cdcs(dpass));
        assertTrue(!asm.cdcs(dpass1));
        assertTrue(!asm.cdcs(dpass2));
        assertTrue(asm.cdcs(cdc));
        assertTrue(asm.cdcs(cdc1));
        assertTrue(asm.cdcs(cdc2));
        assertTrue(!asm.cdcs(dcdc));
        assertTrue(!asm.cdcs(dcdc1));
        assertTrue(!asm.cdcs(dcdc2));
        assertTrue(!asm.cdcs(dpt));
        assertTrue(!asm.cdcs(dai));
        assertTrue(!asm.cdcs(eth));
        assertTrue(!asm.cdcs(eng));
        assertTrue(!asm.cdcs(user));
        assertTrue(!asm.cdcs(custodian));
        assertTrue(!asm.cdcs(custodian1));
        assertTrue(!asm.cdcs(custodian2));
    }

    function testSetDcdcAsm() public {
        address newDcdc = address(new DSToken("NEWTOKEN"));
        asm.setConfig("decimals", b(address(newDcdc)), b(uint(18)), "diamonds");
        asm.setConfig("priceFeed", b(address(newDcdc)), b(feed[cdc]), "diamonds");
        asm.setConfig("dcdcs", b(address(newDcdc)), b(true), "diamonds");
        assertTrue(asm.dcdcs(address(newDcdc)));
        assertTrue(!asm.dcdcs(dpass));
        assertTrue(!asm.dcdcs(dpass1));
        assertTrue(!asm.dcdcs(dpass2));
        assertTrue(!asm.dcdcs(cdc));
        assertTrue(!asm.dcdcs(cdc1));
        assertTrue(!asm.dcdcs(cdc2));
        assertTrue(asm.dcdcs(dcdc));
        assertTrue(asm.dcdcs(dcdc1));
        assertTrue(asm.dcdcs(dcdc2));
        assertTrue(!asm.dcdcs(dpt));
        assertTrue(!asm.dcdcs(dai));
        assertTrue(!asm.dcdcs(eth));
        assertTrue(!asm.dcdcs(eng));
        assertTrue(!asm.dcdcs(user));
        assertTrue(!asm.dcdcs(custodian));
        assertTrue(!asm.dcdcs(custodian1));
        assertTrue(!asm.dcdcs(custodian2));
    }

    function testSetDcdcStoppedAsm() public {
        address newDcdc = address(new DSToken("NEWTOKEN"));
        asm.setConfig("decimals", b(address(newDcdc)), b(uint(18)), "diamonds");
        asm.setConfig("priceFeed", b(address(newDcdc)), b(feed[cdc]), "diamonds");
        asm.setConfig("dcdcs", b(address(newDcdc)), b(true), "diamonds");
        assertTrue(asm.dcdcs(address(newDcdc)));
        assertTrue(!asm.dcdcs(dpass));
        assertTrue(!asm.dcdcs(dpass1));
        assertTrue(!asm.dcdcs(dpass2));
        assertTrue(!asm.dcdcs(cdc));
        assertTrue(!asm.dcdcs(cdc1));
        assertTrue(!asm.dcdcs(cdc2));
        assertTrue(asm.dcdcs(dcdc));
        assertTrue(asm.dcdcs(dcdc1));
        assertTrue(asm.dcdcs(dcdc2));
        assertTrue(!asm.dcdcs(dpt));
        assertTrue(!asm.dcdcs(dai));
        assertTrue(!asm.dcdcs(eth));
        assertTrue(!asm.dcdcs(eng));
        assertTrue(!asm.dcdcs(user));
        assertTrue(!asm.dcdcs(custodian));
        assertTrue(!asm.dcdcs(custodian1));
        assertTrue(!asm.dcdcs(custodian2));
    }
    function testSetCustodianAsm() public {
        address custodian_ = address(0xeeeeee);
        asm.setConfig("custodians", b(address(custodian_)), b(true), "diamonds");
        assertTrue(asm.custodians(address(custodian_)));
        assertTrue(!asm.custodians(dpass));
        assertTrue(!asm.custodians(dpass1));
        assertTrue(!asm.custodians(dpass2));
        assertTrue(!asm.custodians(cdc));
        assertTrue(!asm.custodians(cdc1));
        assertTrue(!asm.custodians(cdc2));
        assertTrue(!asm.custodians(dcdc));
        assertTrue(!asm.custodians(dcdc1));
        assertTrue(!asm.custodians(dcdc2));
        assertTrue(!asm.custodians(dpt));
        assertTrue(!asm.custodians(dai));
        assertTrue(!asm.custodians(eth));
        assertTrue(!asm.custodians(eng));
        assertTrue(!asm.custodians(user));
        assertTrue(asm.custodians(custodian));
        assertTrue(asm.custodians(custodian1));
        assertTrue(asm.custodians(custodian2));
    }

    function testGetTotalDpassCustVAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.totalDpassCustV(custodian), price_);
    }

    function testSetOverCollRatioAsm() public {
        asm.setConfig("overCollRatio", b(uint(1.2 ether)), "", "diamonds");
        assertEq(asm.overCollRatio(), 1.2 ether);
    }

    function testSetPayTokensAsm() public {
        address newPayToken = address(new DSToken("PAYTOKEN"));
        asm.setConfig("decimals", b(address(newPayToken)), b(uint(18)), "diamonds");
        asm.setConfig("priceFeed", b(address(newPayToken)), b(feed[cdc]), "diamonds");
        asm.setConfig("payTokens", b(address(newPayToken)), b(true), "diamonds");
        assertTrue(asm.payTokens(address(newPayToken)));
        assertTrue(!asm.payTokens(dpass));
        assertTrue(!asm.payTokens(dpass1));
        assertTrue(!asm.payTokens(dpass2));
        assertTrue(!asm.payTokens(cdc));
        assertTrue(!asm.payTokens(cdc1));
        assertTrue(!asm.payTokens(cdc2));
        assertTrue(!asm.payTokens(dcdc));
        assertTrue(!asm.payTokens(dcdc1));
        assertTrue(!asm.payTokens(dcdc2));
        assertTrue(asm.payTokens(dpt));
        assertTrue(asm.payTokens(dai));
        assertTrue(asm.payTokens(eth));
        assertTrue(asm.payTokens(eng));
        assertTrue(!asm.payTokens(user));
        assertTrue(!asm.payTokens(custodian));
        assertTrue(!asm.payTokens(custodian1));
        assertTrue(!asm.payTokens(custodian2));
    }

    function testSetDecimalsAsm() public {
        address newPayToken = address(new DSToken("PAYTOKEN"));
        asm.setConfig("decimals", b(address(newPayToken)), b(uint(2)), "diamonds");
        asm.setConfig("priceFeed", b(address(newPayToken)), b(feed[cdc]), "diamonds");
        asm.setConfig("payTokens", b(address(newPayToken)), b(true), "diamonds");
        assertTrue(asm.decimals(address(newPayToken)) == 100);
        assertTrue(asm.decimals(cdc) == 1000000000000000000);
        assertTrue(asm.decimals(cdc1) == 1000000000000000000);
        assertTrue(asm.decimals(cdc2) == 1000000000000000000);
        assertTrue(asm.decimals(dcdc) == 1000000000000000000);
        assertTrue(asm.decimals(dcdc1) == 1000000000000000000);
        assertTrue(asm.decimals(dcdc2) == 1000000000000000000);
        assertTrue(asm.decimals(dpt) == 1000000000000000000);
        assertTrue(asm.decimals(dai) == 1000000000000000000);
        assertTrue(asm.decimals(eth) == 1000000000000000000);
        assertTrue(asm.decimals(eng) == 100000000);
    }

    function testSetDustAsm() public {
        uint dust_ = 25334567;
        assertEq(asm.dust(), 1000);
        asm.setConfig("dust", b(uint(dust_)), "", "diamonds");
        assertEq(asm.dust(), dust_);
    }

    function testSetConfigNewRateAsm() public {
        uint rate_ = 10;
        asm.setConfig("rate", b(cdc), b(rate_), "diamonds");
        assertEq(asm.getRate(cdc), rate_);
        assertEq(asm.getRateNewest(cdc), 17 ether);
    }

    function testIsDecimalsSetAsm() public {
        address newPayToken = address(new DSToken("PAYTOKEN"));
        asm.setConfig("decimals", b(address(newPayToken)), b(uint(2)), "diamonds");
        asm.setConfig("priceFeed", b(address(newPayToken)), b(feed[cdc]), "diamonds");
        asm.setConfig("payTokens", b(address(newPayToken)), b(true), "diamonds");
        assertTrue(asm.decimalsSet(address(newPayToken)));
        assertTrue(asm.decimalsSet(cdc));
        assertTrue(asm.decimalsSet(cdc1));
        assertTrue(asm.decimalsSet(cdc2));
        assertTrue(asm.decimalsSet(dcdc));
        assertTrue(asm.decimalsSet(dcdc1));
        assertTrue(asm.decimalsSet(dcdc2));
        assertTrue(asm.decimalsSet(dpt));
        assertTrue(asm.decimalsSet(dai));
        assertTrue(asm.decimalsSet(eth));
        assertTrue(asm.decimalsSet(eng));
    }

    function testGetPriceFeedAsm() public {
        address newPayToken = address(new DSToken("PAYTOKEN"));
        asm.setConfig("decimals", b(address(newPayToken)), b(uint(2)), "diamonds");
        asm.setConfig("priceFeed", b(address(newPayToken)), b(feed[cdc]), "diamonds");
        asm.setConfig("payTokens", b(address(newPayToken)), b(true), "diamonds");
        assertTrue(asm.priceFeed(address(newPayToken)) == feed[cdc]);
        assertTrue(asm.priceFeed(cdc) == feed[cdc]);
        assertTrue(asm.priceFeed(cdc1) == feed[cdc1]);
        assertTrue(asm.priceFeed(cdc2) == feed[cdc2]);
        assertTrue(asm.priceFeed(dcdc) == feed[dcdc]);
        assertTrue(asm.priceFeed(dcdc1) == feed[dcdc1]);
        assertTrue(asm.priceFeed(dcdc2) == feed[dcdc2]);
        assertTrue(asm.priceFeed(dpt) == feed[dpt]);
        assertTrue(asm.priceFeed(dai) == feed[dai]);
        assertTrue(asm.priceFeed(eth) == feed[eth]);
        assertTrue(asm.priceFeed(eng) == feed[eng]);
    }

    function testSetCapCustV() public {
        asm.setCapCustV(custodian, 1.231264 ether);
        asm.setCapCustV(custodian1, 1.231265 ether);
        asm.setCapCustV(custodian2, 1.231266 ether);
        assertEqLog("cust setCapCustV() actually set", asm.capCustV(custodian), 1.231264 ether);
        assertEqLog("cust1 setCapCustV() actually set", asm.capCustV(custodian1), 1.231265 ether);
        assertEqLog("cust2 setCapCustV() actually set", asm.capCustV(custodian2), 1.231266 ether);
    }

    function testGetCdcValuesMintAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        asm.mint(cdc, address(this), 1 ether);
        assertEq(asm.cdcV(cdc), 17 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);
    }

    function testGetCdcValuesMintBurnAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);

        asm.mint(cdc, address(this), 1 ether);
        assertEq(asm.cdcV(cdc), 17 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);

        DSToken(cdc).transfer(address(asm), 1 ether);
        asm.burn(cdc, 0.5 ether);
        assertEq(asm.cdcV(cdc), 8.5 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);
    }

    function testGetDcdcValuesMintAsm() public {
        uint mintAmt = 1 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEq(asm.dcdcV(dcdc), wmul(usdRate[dcdc], mintAmt));
        assertEq(asm.dcdcV(dcdc1), 0 ether);
        assertEq(asm.dcdcV(dcdc2), 0 ether);
    }

    function testMintDcdcValuesMintCapNotReachedAsm() public {
        uint mintAmt = 1 ether;
        uint capCustV_ = wmul(usdRate[dcdc], mintAmt) + .001 ether;
        asm.setCapCustV(custodian1, capCustV_);
        TrustedSASMTester(custodian1).doMintDcdc(dcdc, custodian1, mintAmt);
        assertEq(asm.dcdcV(dcdc), wmul(usdRate[dcdc], mintAmt));
    }

    function testFailMintDcdcValuesMintAsm() public {
        // error Revert ("asm-custodian-reached-maximum-coll-value")
        uint mintAmt = 1 ether;
        uint capCustV_ = wmul(usdRate[dcdc], mintAmt) - .001 ether;
        asm.setCapCustV(custodian1, capCustV_);
        TrustedSASMTester(custodian1).doMintDcdc(dcdc, custodian1, mintAmt);
    }

    function testGetDcdcValuesMintBurnAsm() public {
        uint mintAmt = 10 ether;
        uint burnAmt = 5 ether;
        require(burnAmt <= mintAmt, "test-burnAmt-gt-mintAmt");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        TrustedSASMTester(custodian).doApprove(dcdc, address(asm),uint(-1));
        TrustedSASMTester(custodian).doBurnDcdc(dcdc, custodian, burnAmt);
        assertEq(asm.dcdcV(dcdc), wmul(usdRate[dcdc], mintAmt - burnAmt));
        assertEq(asm.dcdcV(dcdc1), 0 ether);
        assertEq(asm.dcdcV(dcdc2), 0 ether);
    }

    function testGetDcdcValuesMintBurnStoppedAsm() public {
        uint mintAmt = 10 ether;
        uint burnAmt = 5 ether;
        require(burnAmt <= mintAmt, "test-burnAmt-gt-mintAmt");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        TrustedSASMTester(custodian).doApprove(dcdc, address(asm),uint(-1));
        TrustedSASMTester(custodian).doBurnDcdc(dcdc, custodian, burnAmt);
        assertEq(asm.dcdcV(dcdc), wmul(usdRate[dcdc], mintAmt - burnAmt));
        assertEq(asm.dcdcV(dcdc1), 0 ether);
        assertEq(asm.dcdcV(dcdc2), 0 ether);
    }

    function testGetDcdcValuesMintStoppedAsm() public {
        uint mintAmt = 1 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEq(asm.dcdcV(dcdc), wmul(usdRate[dcdc], mintAmt));
        assertEq(asm.dcdcV(dcdc1), 0 ether);
        assertEq(asm.dcdcV(dcdc2), 0 ether);
    }

    function testGetTotalDcdcValuesMintAsm() public {
        uint mintAmt = 131 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEq(asm.totalDcdcCustV(custodian), wmul(usdRate[dcdc], mintAmt));
    }

    function testGetDcdcCustVAsm() public {
        uint mintAmt = 11 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEqLog("dcdc-at-custodian", asm.dcdcCustV(dcdc, custodian), wmul(usdRate[dcdc], mintAmt));
        assertEqLog("dcdc1-custodian-has-none", asm.dcdcCustV(dcdc1, custodian), 0);
        assertEqLog("dcdc2-custodian-has-none", asm.dcdcCustV(dcdc2, custodian), 0);
    }

    function testAddrAsm() public {
        bytes32 b_ = bytes32(uint(0xef));
        assertEq(asm.addr(b_), address(uint(b_)));
    }

    function testGetBasePriceAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.basePrice(dpass, id_), price_);
        asm.setBasePrice(dpass, id_, price_ * 2);
        assertEq(asm.basePrice(dpass, id_), price_ * 2);
        asm.setBasePrice(dpass, id_, price_ * 3);
        assertEq(asm.basePrice(dpass, id_), price_ * 3);
    }

    function testSetBasePriceCapCustVNotReachedAsm() public {
        uint price_ = 100 ether;
        uint capCustV_ = 100.1 ether;
        require( capCustV_ >= price_, "test-customer-cap-gt-price");
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setCapCustV(custodian1, capCustV_);
        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.basePrice(dpass, id_), price_);
    }

    function testSetBasePriceInvalidAsm() public {
        uint price_ = 100 ether;
        uint capCustV_ = 100.1 ether;
        require( capCustV_ >= price_, "test-customer-cap-gt-price");
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "11211211", "invalid", cccc_, 1, b(0xef), "20191107");
        asm.setCapCustV(custodian1, capCustV_);
        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.basePrice(dpass, id_), price_);
        assertEq(asm.totalDpassCustV(custodian1), uint(0));
        assertEq(asm.totalDpassV(), uint(0));
    }

    function testSetBasePriceRemovedAsm() public {
        uint price_ = 100 ether;
        uint capCustV_ = 100.1 ether;
        require( capCustV_ >= price_, "test-customer-cap-gt-price");
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "11211211", "removed", cccc_, 1, b(0xef), "20191107");
        asm.setCapCustV(custodian1, capCustV_);
        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.basePrice(dpass, id_), price_);
        assertEq(asm.totalDpassCustV(custodian1), uint(0));
        assertEq(asm.totalDpassV(), uint(0));
    }

    function testSetBasePriceRedeemedAsm() public {
        uint price_ = 100 ether;
        uint capCustV_ = 100.1 ether;
        require( capCustV_ >= price_, "test-customer-cap-gt-price");
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "11211211", "redeemed", cccc_, 1, b(0xef), "20191107");
        asm.setCapCustV(custodian1, capCustV_);
        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.basePrice(dpass, id_), price_);
        assertEq(asm.totalDpassCustV(custodian1), uint(0));
        assertEq(asm.totalDpassV(), uint(0));
    }

    function testFailSetBasePriceCapCustVReachedAsm() public {
        // error Revert ("asm-custodian-reached-maximum-coll-value")
        uint price_ = 100 ether;
        uint capCustV_ = 80 ether;
        require( capCustV_ <= price_, "test-customer-cap-lt-price");
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setCapCustV(custodian1, capCustV_);
        asm.setBasePrice(dpass, id_, price_);
    }

    function testSetBasePriceLowerCapCustVReachedAsm() public {
        // error Revert ("asm-custodian-reached-maximum-coll-value")
        uint price_ = 100 ether;
        uint capCustV_ = 80 ether;
        require( capCustV_ <= price_, "test-customer-cap-lt-price");
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        asm.setCapCustV(custodian1, capCustV_);
        asm.setBasePrice(dpass, id_, capCustV_);
    }
/*
    function testStoppedMintStillWorksAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        asm.stop();
        asm.mint(cdc, address(this), 1 ether);
        asm.start();
        assertEq(asm.cdcV(cdc), 17 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);

        TestFeedLike(feed[cdc]).setRate(30 ether);
        asm.setCdcV(cdc);

        assertEq(asm.cdcV(cdc), 30 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);
    }
*/
    function testUpdateCdcValueAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);

        asm.mint(cdc, address(this), 1 ether);
        assertEq(asm.cdcV(cdc), 17 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);

        TestFeedLike(feed[cdc]).setRate(30 ether);
        asm.setCdcV(cdc);

        assertEq(asm.cdcV(cdc), 30 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);
    }
/*
    function testFailUpdateCdcValueAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);

        asm.mint(cdc, address(this), 1 ether);
        assertEq(asm.cdcV(cdc), 17 ether);
        assertEq(asm.cdcV(cdc1), 0 ether);
        assertEq(asm.cdcV(cdc2), 0 ether);

        TestFeedLike(feed[cdc]).setRate(30 ether);
        asm.stop();
        asm.setCdcV(cdc);
    }
*/
    function testUpdateTotalDcdcValueAsm() public {
        uint mintAmt = 11 ether;
        uint rate_ = 30 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEq(asm.dcdcCustV(dcdc, custodian), wmul(usdRate[dcdc], mintAmt));
        assertEq(asm.dcdcCustV(dcdc1, custodian), 0);
        assertEq(asm.dcdcCustV(dcdc2, custodian), 0);

        TestFeedLike(feed[dcdc]).setRate(rate_);
        asm.setTotalDcdcV(dcdc);
        assertEq(asm.totalDcdcV(), wmul(rate_, mintAmt));

    }
/*
    function testFailUpdateTotalDcdcValueAsm() public {
        uint mintAmt = 11 ether;
        uint rate_ = 30 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEq(asm.dcdcCustV(dcdc, custodian), wmul(usdRate[dcdc], mintAmt));
        assertEq(asm.dcdcCustV(dcdc1, custodian), 0);
        assertEq(asm.dcdcCustV(dcdc2, custodian), 0);

        TestFeedLike(feed[dcdc]).setRate(rate_);
        asm.stop();
        asm.setTotalDcdcV(dcdc);
    }
*/
    function testUpdateDcdcValueAsm() public {
        uint mintAmt = 11 ether;
        uint rate_ = 30 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEq(asm.dcdcCustV(dcdc, custodian), wmul(usdRate[dcdc], mintAmt));
        assertEq(asm.dcdcCustV(dcdc1, custodian), 0);
        assertEq(asm.dcdcCustV(dcdc2, custodian), 0);

        TestFeedLike(feed[dcdc]).setRate(rate_);
        asm.setDcdcV(dcdc, custodian);
        assertEq(asm.dcdcCustV(dcdc, custodian), wmul(rate_, mintAmt));
    }
/*
    function testFailUpdateDcdcValueStoppedAsm() public {
        uint mintAmt = 11 ether;
        uint rate_ = 30 ether;
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintAmt);
        assertEq(asm.dcdcCustV(dcdc, custodian), wmul(usdRate[dcdc], mintAmt));
        assertEq(asm.dcdcCustV(dcdc1, custodian), 0);
        assertEq(asm.dcdcCustV(dcdc2, custodian), 0);

        TestFeedLike(feed[dcdc]).setRate(rate_);
        asm.stop();
        asm.setDcdcV(dcdc, custodian);
    }
*/
    function testWmulVAsm() public {
        for(uint i = 77; i >= 1; i--) {
            asm.setConfig("decimals", b(cdc), b(i), "diamonds");
            assertEq(asm.wmulV(1 ether, 1 ether, cdc), uint(10) ** 18 * 1 ether / 10 ** i);
        }
        asm.setConfig("decimals", b(cdc), b(uint(0)), "diamonds");
        assertEq(asm.wmulV(1 ether, 1 ether, cdc), uint(10) ** 18 * 1 ether );
    }

    function testWdivTAsm() public {
        for(uint i = 58; i >= 1; i--) {
            asm.setConfig("decimals", b(cdc), b(i), "diamonds");
            assertEq(asm.wdivT(1 ether, 1 ether, cdc),  10 ** i);
        }
        asm.setConfig("decimals", b(cdc), b(uint(0)), "diamonds");
        assertEq(asm.wdivT(1 ether, 1 ether, cdc), 1);
    }

    function testGetTokenPuchaseRateCdcAsm() public {
        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        require(mintCdc * usdRate[cdc] <= mintDcdcAmt * usdRate[dcdc], "test-mintCdc-too-high");
        asm.setConfig("payTokens", b(cdc), b(true), "diamonds");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        TrustedSASMTester(custodian).doMint(cdc, user, mintCdc);
        TrustedSASMTester(user).doSendToken(cdc, user, address(asm), mintCdc);
        asm.notifyTransferFrom(cdc, user, address(asm), mintCdc);
        assertEq(asm.tokenPurchaseRate(cdc), 0); // does not update tokenPurchaseRate as token is burnt
    }

    function testGetTokenPuchaseRateDaiAsm() public {
        uint amt = 10 ether;
        DSToken(dai).transfer(user, amt);
        TrustedSASMTester(user).doSendToken(dai, user, address(asm), amt);
        asm.notifyTransferFrom(dai, user, address(asm), amt);
        assertEq(asm.tokenPurchaseRate(dai), usdRate[dai]); // does not update tokenPurchaseRate as token is burnt
        assertEq(DSToken(dai).balanceOf(address(asm)), amt);
    }

    function testGetTokenPuchaseRateDaiTwiceAsm() public {
        uint amt = 10 ether;
        uint newRate = 1.02 ether;
        DSToken(dai).transfer(user, amt);
        TrustedSASMTester(user).doSendToken(dai, user, address(asm), amt / 2);
        asm.notifyTransferFrom(dai, user, address(asm), amt / 2);
        assertEq(asm.tokenPurchaseRate(dai), usdRate[dai]);
        assertEq(DSToken(dai).balanceOf(address(asm)), amt / 2);
        TestFeedLike(feed[dai]).setRate(newRate);

        TrustedSASMTester(user).doSendToken(dai, user, address(asm), amt / 2);
        asm.notifyTransferFrom(dai, user, address(asm), amt / 2);
        assertEq(asm.tokenPurchaseRate(dai), (usdRate[dai] * amt / 2 + newRate * amt / 2) / amt);
    }

    function testGetTotalPaidVDaiAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        uint amt = 10 ether;
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107");

        asm.setConfig("setApproveForAll", b(dpass), b(exchange), b(true));
        asm.setBasePrice(dpass, id_, price_);
        assertTrue(Dpass(dpass).isApprovedForAll(address(asm), exchange));
        asm.notifyTransferFrom(dpass, address(asm), user, id_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id_);

        DSToken(dai).transfer(user, amt);
        TrustedSASMTester(user).doApprove(dai, exchange, amt);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), amt);
        asm.notifyTransferFrom(dai, user, address(asm), amt);

        TrustedSASMTester(custodian).doWithdraw(dai, amt);
        assertEq(asm.totalPaidCustV(custodian), wmul(amt, usdRate[dai]));
    }

    function testGetTotalDpassSoldVAsm() public logs_gas {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        uint amt = 10 ether;
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107");

        asm.setConfig("setApproveForAll", b(dpass), b(exchange), b(true));
        asm.setBasePrice(dpass, id_, price_);
        assertTrue(Dpass(dpass).isApprovedForAll(address(asm), exchange));
        asm.notifyTransferFrom(dpass, address(asm), user, id_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id_);

        DSToken(dai).transfer(user, amt);
        TrustedSASMTester(user).doApprove(dai, exchange, amt);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), amt);
        asm.notifyTransferFrom(dai, user, address(asm), amt);

        TrustedSASMTester(custodian).doWithdraw(dai, amt);
        assertEq(asm.dpassSoldCustV(custodian), price_);
    }

    function testGetTotalDpassVAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.totalDpassV(), price_);

        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11111111", "valid", cccc_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.totalDpassV(), mul(2, price_));
    }

    function testGetTotalDcdcVAsm() public {
        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        require(mintCdc * usdRate[cdc] <= mintDcdcAmt * usdRate[dcdc], "test-mintCdc-too-high");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        assertEq(asm.totalDcdcV(), wmul(usdRate[dcdc], mintDcdcAmt));
    }

    function testGetTotalCdcVAsm() public logs_gas {
        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        require(mintCdc * usdRate[cdc] <= mintDcdcAmt * usdRate[dcdc], "test-mintCdc-too-high");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        TrustedSASMTester(custodian).doMint(cdc, user, mintCdc);
        assertEq(asm.totalCdcV(), wmul(mintCdc, usdRate[cdc])); // does not update tokenPurchaseRate as token is burnt
    }

    function testNotifyTransferFromDpassBuyPriceAsm() public {
        uint price_ = 101 ether;
        uint buyPrice_ = 90 ether;
        uint id_;
        bytes20 cccc_ = "BR,I3,D,10.00";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "3333333", "sale", cccc_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id_, price_);
        asm.setConfig("payTokens", b(dpass), b(true), "diamonds");
        TrustedSASMTester(exchange).setBuyPrice(buyPrice_);
        asm.setConfig("setApproveForAll", b(dpass), b(exchange), b(true));
        TrustedSASMTester(exchange).doNotifyTransferFrom(dpass, address(asm), user, id_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id_);

        assertEqLog("dpassSolcDustV ok", asm.dpassSoldCustV(custodian), buyPrice_);
        assertEqLog("totalDpassCustV ok", asm.totalDpassCustV(custodian), uint(0));
        assertEqLog("totalDpassV", asm.totalDpassV(), uint(0));
    }

    function testNotifyTransferFromDpassAsm() public {
        uint price_ = 101 ether;
        uint id_;
        bytes20 cccc_ = "BR,I3,D,10.00";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(user, custodian, "GIA", "3333333", "sale", cccc_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id_, price_);
        asm.setConfig("payTokens", b(dpass), b(true), "diamonds");
        TrustedSASMTester(user).doSendDpassToken(dpass, user, address(asm), id_);
        TrustedSASMTester(exchange).doNotifyTransferFrom(dpass, user, address(asm), id_);

        assertEqLog("totalDpassCustV ok", asm.totalDpassCustV(custodian), price_);
        assertEqLog("totalDpassV", asm.totalDpassV(), price_);
    }

    function testFailNotifyTransferFromUserCustodianAsm() public {
        uint amount = 10 ether;
        TrustedSASMTester(exchange).doNotifyTransferFrom(dai, user, custodian, amount);
    }

    function testFailNotifyTransferFromCustodianUserAsm() public {
        uint amount = 10 ether;
        TrustedSASMTester(exchange).doNotifyTransferFrom(dai, custodian, user, amount);
    }

    function testWithdrawDpassAsm() public {
        uint price_ = 100 ether;
        uint price1_ = 100 ether;
        uint id_;
        uint id1_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes20 cccc1_ = "BR,I1,G,5.99";
        uint amtToWithdraw = 100 ether;
        require(amtToWithdraw <= price_ + price1_, "test-too-high-withdrawal value");

        Dpass(dpass).setCccc(cccc_, true);
        Dpass(dpass).setCccc(cccc1_, true);
        asm.setConfig("setApproveForAll", b(dpass), b(exchange), b(true));

        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id_, price_);
        asm.notifyTransferFrom(dpass, address(asm), user, id_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id_);

        DSToken(dai).transfer(user, price_);
        TrustedSASMTester(user).doApprove(dai, exchange, price_);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), price_);
        asm.notifyTransferFrom(dai, user, address(asm), price_);

        id1_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "22222222", "sale", cccc1_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id1_, price1_);
        asm.notifyTransferFrom(dpass, address(asm), user, id1_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id1_);

        DSToken(dai).transfer(user, price1_);
        TrustedSASMTester(user).doApprove(dai, exchange, price1_);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), price1_);
        asm.notifyTransferFrom(dai, user, address(asm), price1_);

        TrustedSASMTester(custodian).doWithdraw(dai, amtToWithdraw);
        assertEq(asm.totalPaidCustV(custodian), wmul(amtToWithdraw, usdRate[dai]));

    }

    function testFailWithdrawDpassTryToWithdrawMoreAsm() public {
        uint price_ = 100 ether;
        uint price1_ = 100 ether;
        uint id_;
        uint id1_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes20 cccc1_ = "BR,I1,G,5.99";
        uint amtToWithdraw = 200 ether;
        require(amtToWithdraw <= price_ + price1_, "test-too-high-withdrawal value");

        Dpass(dpass).setCccc(cccc_, true);
        Dpass(dpass).setCccc(cccc1_, true);
        asm.setConfig("setApproveForAll", b(dpass), b(exchange), b(true));

        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id_, price_);
        asm.notifyTransferFrom(dpass, address(asm), user, id_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id_);

        DSToken(dai).transfer(user, price_);
        TrustedSASMTester(user).doApprove(dai, exchange, price_);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), price_);
        asm.notifyTransferFrom(dai, user, address(asm), price_);

        id1_ = Dpass(dpass).mintDiamondTo(address(asm), custodian1, "GIA", "22222222", "valid", cccc1_, 1, b(0xef), "20191107");

        asm.setBasePrice(dpass, id1_, price1_);
        asm.notifyTransferFrom(dpass, address(asm), user, id1_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id1_);

        DSToken(dai).transfer(user, price1_);
        TrustedSASMTester(user).doApprove(dai, exchange, price1_);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), price1_);
        asm.notifyTransferFrom(dai, user, address(asm), price1_);

        TrustedSASMTester(custodian).doWithdraw(dai, amtToWithdraw);
        assertEq(asm.totalPaidCustV(custodian), wmul(amtToWithdraw, usdRate[dai]));

    }

    function testWithdrawWhenDcdcAsm() public {

        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        uint price_ = 5 ether;
        require(price_ < wmul(mintCdc, usdRate[cdc]), "test-price-too-high");
        require(mintCdc * usdRate[cdc] <= mintDcdcAmt * usdRate[dcdc], "test-mintCdc-too-high");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        TrustedSASMTester(custodian).doMint(cdc, user, mintCdc);

        // user pays for cdc
        DSToken(dai).transfer(user, price_);
        TrustedSASMTester(user).doApprove(dai, exchange, price_);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), price_);
        asm.notifyTransferFrom(dai, user, address(asm), price_);
        TrustedSASMTester(custodian).doWithdraw(dai, price_);

    }

    function testFailWithdrawWhenDcdcAsm() public {

        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        uint delta = 1 ether;
        uint cdcV = wmul(mintCdc, usdRate[cdc]);
        uint price_ = add(cdcV, delta);
        require(price_ > wmul(mintCdc, usdRate[cdc]), "test-price-too-high");
        require(mintCdc * usdRate[cdc] <= mintDcdcAmt * usdRate[dcdc], "test-mintCdc-too-high");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        TrustedSASMTester(custodian).doMint(cdc, user, mintCdc);

        // user pays for cdc
        DSToken(dai).transfer(user, price_);
        TrustedSASMTester(user).doApprove(dai, exchange, price_);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), price_);
        asm.notifyTransferFrom(dai, user, address(asm), price_);

        //withdraw will fail even if contract does have enough token but custodian is not entitled to it
        TrustedSASMTester(custodian).doWithdraw(dai, price_);

    }
/*
    function testGetWithdrawValueCdcAsm() public {

        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        uint price_ = 5 ether;
        require(price_ < wmul(mintCdc, usdRate[cdc]), "test-price-too-high");
        require(mintCdc * usdRate[cdc] <= mintDcdcAmt * usdRate[dcdc], "test-mintCdc-too-high");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        TrustedSASMTester(custodian).doMint(cdc, user, mintCdc);

        // user pays for cdc
        DSToken(dai).transfer(user, price_);
        TrustedSASMTester(user).doApprove(dai, exchange, price_);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), price_);
        asm.notifyTransferFrom(dai, user, address(asm), price_);

        assertEq(asm.withdrawV(custodian), wmul(mintCdc, usdRate[cdc]));
    }

    function testGetWithdrawValueDpassAsm() public {

        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107");

        asm.setConfig("setApproveForAll", b(dpass), b(exchange), b(true));
        asm.setBasePrice(dpass, id_, price_);
        asm.notifyTransferFrom(dpass, address(asm), user, id_);
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id_);

        assertEq(asm.withdrawV(custodian), price_);
    }
*/
    function testGetAmtForSaleDcdcAsm() public {

        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        uint price_ = 5 ether;
        uint overCollRatio_ = 1.2 ether;
        require(overCollRatio_ > 0, "test-overcoll-ratio-zero");
        require(price_ < wmul(mintCdc, usdRate[cdc]), "test-price-too-high");
        require(wmul(mintCdc, usdRate[cdc]) <= wmul(mintDcdcAmt, usdRate[dcdc]), "test-mintCdc-too-high");
        asm.setConfig("decimals", b(cdc), b(uint(18)), "diamonds");
        asm.setConfig("overCollRatio", b(overCollRatio_), "", "diamonds");
        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        assertEq(asm.getAmtForSale(cdc), wdiv(wdiv(wmul(mintDcdcAmt, usdRate[dcdc]), overCollRatio_) , usdRate[cdc]));
    }

    function testGetAmtForSaleDpassAsm() public {

        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        uint overCollRatio_ = 1.2 ether;

        require(overCollRatio_ > 0, "test-overcoll-ratio-zero");

        Dpass(dpass).setCccc(cccc_, true);
        asm.setConfig("decimals", b(cdc), b(uint(18)), "diamonds");
        asm.setConfig("overCollRatio", b(overCollRatio_), "", "diamonds");

        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        assertEq(asm.getAmtForSale(cdc), wdiv(wdiv(price_, overCollRatio_), usdRate[cdc]));
    }

    function testGetAmtForSaleDpassDcdcCdcAsm() public {

        uint mintDcdcAmt = 11 ether;
        uint mintCdc = 1 ether;
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        uint overCollRatio_ = 1.2 ether;

        require(overCollRatio_ > 0, "test-overcoll-ratio-zero");
        require(wmul(mintCdc, usdRate[cdc]) <= add(wmul(mintDcdcAmt, usdRate[dcdc]), price_), "test-mintCdc-too-high");

        Dpass(dpass).setCccc(cccc_, true);
        asm.setConfig("decimals", b(cdc), b(uint(18)), "diamonds");
        asm.setConfig("overCollRatio", b(overCollRatio_), "", "diamonds");

        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        TrustedSASMTester(custodian).doMint(cdc, user, mintCdc);
        assertEq(
            asm.getAmtForSale(cdc),
            wdiv(
                sub(
                    wdiv(
                        add(
                            price_,
                            wmul(
                                mintDcdcAmt,
                                usdRate[dcdc])),
                        overCollRatio_),
                    wmul(
                        mintCdc,
                        usdRate[cdc])),
                usdRate[cdc]));
    }

    function testUpdateCollateralDpassAsm() public {

        asm.setCollateralDpass(1 ether, 0, custodian);
        assertEq(asm.totalDpassCustV(custodian), 1 ether);
        assertEq(asm.totalDpassV(), 1 ether);

        asm.setCollateralDpass(0, 1 ether, custodian);
        assertEq(asm.totalDpassCustV(custodian), 0 ether);
        assertEq(asm.totalDpassV(), 0 ether);
    }

    function testUpdateCollateralDcdcAsm() public {

        asm.setCollateralDcdc(1 ether, 0, custodian);
        assertEq(asm.totalDcdcCustV(custodian), 1 ether);
        assertEq(asm.totalDcdcV(), 1 ether);

        asm.setCollateralDcdc(0, 1 ether, custodian);
        assertEq(asm.totalDcdcCustV(custodian), 0 ether);
        assertEq(asm.totalDcdcV(), 0 ether);
    }

    function testBurnAsm() public {
        uint mintCdc = 1 ether;
        uint mintDcdcAmt = 11 ether;
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        uint overCollRatio_ = 1.2 ether;

        require(overCollRatio_ > 0, "test-overcoll-ratio-zero");
        require(wmul(mintCdc, usdRate[cdc]) <= add(wmul(mintDcdcAmt, usdRate[dcdc]), price_), "test-mintCdc-too-high");

        Dpass(dpass).setCccc(cccc_, true);
        asm.setConfig("decimals", b(cdc), b(uint(18)), "diamonds");
        asm.setConfig("overCollRatio", b(overCollRatio_), "", "diamonds");

        TrustedSASMTester(custodian).doMintDcdc(dcdc, custodian, mintDcdcAmt);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107");
        asm.setBasePrice(dpass, id_, price_);
        TrustedSASMTester(custodian).doMint(cdc, user, mintCdc);
        TrustedSASMTester(user).doSendToken(cdc, user, address(asm), mintCdc);
        asm.burn(cdc, mintCdc / 2);
        assertEq(asm.totalCdcV(), wmul(mintCdc / 2, usdRate[cdc]));
        assertEq(asm.cdcV(cdc), wmul(mintCdc / 2, usdRate[cdc]));
        // assertEq(asm.withdrawV(custodian), wmul(mintCdc / 2, usdRate[cdc]));
        assertEq(asm.getAmtForSale(cdc), wdiv(sub(wdiv(add(price_, wmul(mintDcdcAmt, usdRate[dcdc])), overCollRatio_), wmul(mintCdc / 2, usdRate[cdc])), usdRate[cdc]));
    }

    function testMintDpassAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIa", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        (
            bytes32 issuer,
            bytes32 report,
            bytes32 state,
            bytes20 cccc,
            uint24 carat,
            bytes32 attributesHash) = Dpass(dpass).getDiamond(id_);

        assertEqLog("owner is asm", Dpass(dpass).ownerOf(id_), address(asm));
        assertEqLog("custodian is custodian", Dpass(dpass).getCustodian(id_), custodian);
        assertEqLog("GIA is GIA", Dpass(dpass).getCustodian(id_), custodian);
        assertEqLog("issuer is what is set", issuer, "GIa");
        assertEqLog("report is what is set", report, "11211211");
        assertEqLog("state is what is set", state, "sale");
        assertEqLog("cccc is what is set", cccc, cccc_);
        assertEqLog("carat is what is set", carat, 1);
        assertEqLog("attr.hash is what is set", attributesHash, b(0xef));
        assertEqLog( "price is what was set", asm.basePrice(dpass, id_), price_);
    }

    function testMintDpassCapCustSetAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        asm.setCapCustV(custodian1, price_);
        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian1).doMintDpass(dpass, custodian1, "GIa", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        (
            bytes32 issuer,
            bytes32 report,
            bytes32 state,
            bytes20 cccc,
            uint24 carat,
            bytes32 attributesHash) = Dpass(dpass).getDiamond(id_);

        assertEqLog("owneo is asm", Dpass(dpass).ownerOf(id_), address(asm));
        assertEqLog("custodian1 is custodian1", Dpass(dpass).getCustodian(id_), custodian1);
        assertEqLog("GIA is GIA", Dpass(dpass).getCustodian(id_), custodian1);
        assertEqLog("issuer is what is set", issuer, "GIa");
        assertEqLog("report is what is set", report, "11211211");
        assertEqLog("state is what is set", state, "sale");
        assertEqLog("cccc is what is set", cccc, cccc_);
        assertEqLog("carat is what is set", carat, 1);
        assertEqLog("attr.hash is what is set", attributesHash, b(0xef));
        assertEqLog( "price is what was set", asm.basePrice(dpass, id_), price_);
    }

    function testFailMintDpassCapCustSetAsm() public {
        // error Revert ("asm-custodian-reached-maximum-coll-value")
        uint price_ = 100 ether;
        uint capCustV_ = price_ - .0001 ether;
        require(capCustV_ < price_, "test-cap-lt-dpass-value");
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        asm.setCapCustV(custodian1, capCustV_);
        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian1).doMintDpass(dpass, custodian1, "GIa", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);

    }

    function testFailCustodianMintDpassNotToSelfAsm() public {
        // error Revert ("asm-mnt-can-not-mint-for-dst")
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";

        Dpass(dpass).setCccc(cccc_, true);

        guard.permit(address(custodian), address(asm), ANY);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, address(asm), "GIa", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
    }

    function testFailCustodianMintNotDpassAsm() public {
        // error Revert ("asm-mnt-not-a-dpass-token")
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";

        Dpass(dpass).setCccc(cccc_, true);

        guard.permit(address(custodian), address(asm), ANY);
        id_ = TrustedSASMTester(custodian).doMintDpass(cdc, address(asm), "GIa", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
    }

    function testSetStateDpassAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "invalid";

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
    }

    function testSetStateDpassSaleInvalidCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "invalid";

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), 0);

    }

    function testSetStateDpassSaleRemovedCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "removed"; // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        Dpass(dpass).enableTransition("sale", stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), 0);

    }

    function testSetStateDpassValidInvalidCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "invalid";

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107", price_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), 0);

    }

    function testSetStateDpassValidRemovedCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "removed"; // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "valid", cccc_, 1, b(0xef), "20191107", price_);
        Dpass(dpass).enableTransition("valid", stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), 0);

    }

    function testSetStateDpassRedeemedValidCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "redeemed"; // DO NOT CHANGE THIS
        bytes8 stateTo_ = "valid";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);
        assertEqLog("minted redeemed no coll change", asm.totalDpassCustV(custodian), 0);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), price_);

    }

    function testSetStateDpassInvalidValidCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "invalid"; // DO NOT CHANGE THIS
        bytes8 stateTo_ = "valid";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);
        assertEqLog("minted redeemed no coll change", asm.totalDpassCustV(custodian), 0);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), price_);

    }

    function testSetStateDpassRemovedValidCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "removed"; // DO NOT CHANGE THIS
        bytes8 stateTo_ = "valid";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);
        assertEqLog("minted redeemed no coll change", asm.totalDpassCustV(custodian), 0);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), price_);

    }

    function testSetStateDpassRedeemedSaleCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "redeemed"; // DO NOT CHANGE THIS
        bytes8 stateTo_ = "sale";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);
        assertEqLog("minted redeemed no coll change", asm.totalDpassCustV(custodian), 0);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), price_);

    }

    function testSetStateDpassInvalidSaleCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "invalid"; // DO NOT CHANGE THIS
        bytes8 stateTo_ = "sale";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);
        assertEqLog("minted redeemed no coll change", asm.totalDpassCustV(custodian), 0);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), price_);

    }

    function testSetStateDpassRemovedSaleCollateralChangeAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "removed"; // DO NOT CHANGE THIS
        bytes8 stateTo_ = "sale";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);
        assertEqLog("minted redeemed no coll change", asm.totalDpassCustV(custodian), 0);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to zero", asm.totalDpassCustV(custodian), price_);

    }

    function testSetStateDpassSaleRemoveCollateralChangeAsm() public {
        uint price_ = 100 ether;
        price1 = 200 ether;
        uint cdcV_ = 95.23 ether;
        overCollRemoveRatio = 1.05 ether;
        uint cdcT_ = asm.wdivT(cdcV_, usdRate[cdc], cdc);
        uint id_;
        uint id1_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "sale";     // DO NOT CHANGE THIS
        bytes8 stateTo_ = "removed";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        asm.setConfig("overCollRatio", b(uint(overCollRemoveRatio)), "", "diamonds");
        asm.setConfig("overCollRemoveRatio", b(uint(overCollRemoveRatio)), "", "diamonds");
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);


        asm.mint(cdc, address(this), cdcT_);

        id1_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211212", stateFrom_, cccc_, 1, b(0xef), "20191107", price1);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id1_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id1_);
        assertEqLog("state did change", state, stateTo_);
        assertEqLog("collateral went to price_", asm.totalDpassCustV(custodian), price_);

    }
    uint daiV;
    uint daiT;
    uint price2;
    uint id;
    uint id1;
    uint id2;
    function testFailSetStateDpassSaleRemoveCollateralChangePaidLessThanSoldAsm() public {
        // error Revert ("asm-too-much-withdrawn")
        uint price_ = 50 ether;
        price1 = 50 ether;
        price2 = 1000 ether;
        uint cdcV_ = 95.23 ether;
        daiV = cdcV_;
        overCollRemoveRatio = 1.05 ether;
        uint cdcT_ = asm.wdivT(cdcV_, usdRate[cdc], cdc);
        daiT = asm.wdivT(daiV, usdRate[dai], dai);
        uint id_;
        uint id1_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateFrom_ = "sale";     // DO NOT CHANGE THIS
        bytes8 stateTo_ = "removed";    // DO NOT CHANGE THIS

        Dpass(dpass).setCccc(cccc_, true);
        asm.setConfig("overCollRatio", b(uint(overCollRemoveRatio)), "", "diamonds");
        asm.setConfig("overCollRemoveRatio", b(uint(overCollRemoveRatio)), "", "diamonds");
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", stateFrom_, cccc_, 1, b(0xef), "20191107", price_);



        id1_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211212", stateFrom_, cccc_, 1, b(0xef), "20191107", price1);
        asm.mint(cdc, address(this), cdcT_);
        DSToken(dai).transfer(address(asm), daiT);
        asm.notifyTransferFrom(dai, address(this), address(asm), daiT);
        TrustedSASMTester(custodian1).doWithdraw(dai, daiT);

        id2 = TrustedSASMTester(custodian1).doMintDpass(dpass, custodian1, "GIA", "11211213", stateFrom_, cccc_, 1, b(0xef), "20191107", price2);
        Dpass(dpass).enableTransition(stateFrom_, stateTo_);
        asm.setStateDpass(dpass, id1_, stateTo_);
        (
            ,
            ,
            bytes32 state,
            ,
            ,
            ) = Dpass(dpass).getDiamond(id1_);
        assertEqLog("state did change", state, stateTo_);
    }

/*
    function testSetStateDpassArrayAsm() public {
        uint price_ = 100 ether;
        uint id_;
        uint id1_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "invalid";
        uint[] memory tokenIds_;

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        id1_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "2222222", "valid", cccc_, 1, b(0xef), "20191107", price_);
        tokenIds_ = new uint[](2);
        tokenIds_[0] = id_;
        tokenIds_[1] = id1_;

        TrustedSASMTester(custodian).doSetStateDpass(dpass, tokenIds_, stateTo_);

        (
            bytes32 issuer,
            bytes32 report,
            bytes32 state,
            bytes20 cccc,
            uint24 carat,
            bytes32 attributesHash) = Dpass(dpass).getDiamond(id_);

        assertEqLog("state did change id_", state, stateTo_);

        (
            issuer,
            report,
            state,
            cccc,
            carat,
            attributesHash) = Dpass(dpass).getDiamond(id1_);
        assertEqLog("state did change id1_", state, stateTo_);
    }
*/
    function testFailAuthCheckSetConfigAsm() public {
        uint overCollRatio_ = 1.1 ether;
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setConfig("overCollRatio", b(overCollRatio_), "", "diamonds");
    }

    function testFailAuthCheckSetRateAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setRate(cdc, 1 ether);
    }

    function testFailAuthCheckSetCapCustVAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setCapCustV(custodian, 1 ether);
    }

    function testFailAuthCheckGetRateNewestAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.getRateNewest(cdc);
    }

    function testFailAuthCheckGetRateAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.getRate(cdc);
    }

    function testFailAuthCheckSetBasePriceAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setBasePrice(dpass, 1, 1 ether);
    }

    function testFailAuthCheckNotifyTransferFromAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.notifyTransferFrom(dpass, address(asm), user, 1);
    }

    function testFailAuthCheckBurnAsm() public {
        asm.mint(cdc, address(this), 1 ether);
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);


        DSToken(cdc).transfer(address(asm), 1 ether);
        asm.burn(cdc, 0.5 ether);
    }

    function testFailAuthCheckMintAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        guard.forbid(address(this), address(asm), ANY);
        asm.mint(cdc, address(this), 1 ether);
    }

    function testFailAuthCheckMintDcdcAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        guard.forbid(address(this), address(asm), ANY);
        asm.mintDcdc(dcdc, address(this), 1 ether);
    }

    function testFailAuthCheckBurnDcdcAsm() public {
        asm.mintDcdc(dcdc, address(this), 1 ether);
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.burnDcdc(dcdc, address(this), 1 ether);
    }

    function testFailAuthCheckMintDpassAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";

        Dpass(dpass).setCccc(cccc_, true);
        asm.setOwner(user);
        guard.forbid(custodian, address(asm), bytes4(keccak256("mintDpass(address,address,bytes3,bytes16,bytes8,bytes20,uint24,bytes32,bytes8,uint256)")));

        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
    }

    function testFailAuthCheckSetStateDpassAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "invalid";

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setStateDpass(dpass, id_, stateTo_);
    }

    /*
    function testFailAuthCheckSetStateDpassArrayAsm() public {
        uint price_ = 100 ether;
        uint id_;
        uint id1_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        bytes8 stateTo_ = "invalid";
        uint[] memory tokenIds_;

        Dpass(dpass).setCccc(cccc_, true);
        id_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107", price_);
        id1_ = TrustedSASMTester(custodian).doMintDpass(dpass, custodian, "GIA", "2222222", "valid", cccc_, 1, b(0xef), "20191107", price_);
        tokenIds_ = new uint[](2);
        tokenIds_[0] = id_;
        tokenIds_[1] = id1_;

        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setStateDpass(dpass, tokenIds_, stateTo_);
    }*/

    function testFailAuthCheckWithdrawAsm() public {
        uint price_ = 100 ether;
        uint id_;
        bytes20 cccc_ = "BR,IF,F,0.01";
        uint amt = 10 ether;
        Dpass(dpass).setCccc(cccc_, true);
        id_ = Dpass(dpass).mintDiamondTo(address(asm), custodian, "GIA", "11211211", "sale", cccc_, 1, b(0xef), "20191107");

        asm.setConfig("setApproveForAll", b(dpass), b(exchange), b(true));
        asm.setBasePrice(dpass, id_, price_);
        assertTrue(Dpass(dpass).isApprovedForAll(address(asm), exchange));
        TrustedSASMTester(exchange).doSendDpassToken(dpass, address(asm), user, id_);
        asm.notifyTransferFrom(dpass, address(asm), user, id_);

        DSToken(dai).transfer(user, amt);
        TrustedSASMTester(user).doApprove(dai, exchange, amt);
        TrustedSASMTester(exchange).doSendToken(dai, user, address(asm), amt);
        asm.notifyTransferFrom(dai, user, address(asm), amt);

        guard.forbid(custodian, address(asm), bytes4(keccak256("withdraw(address,uint256)")));
        TrustedSASMTester(custodian).doWithdraw(dai, amt);
    }

    function testFailAuthCheckUpdateCollateralDpassAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setCollateralDpass(1 ether, 0,  custodian);
    }

    function testFailAuthCheckUpdateCollateralDcdcAsm() public {
        asm.setOwner(user);
        guard.forbid(address(this), address(asm), ANY);

        asm.setCollateralDcdc(1 ether, 0,  custodian);
    }
//----------------------end-of-tests-------------------------------------------------------------

    /*
    * @dev Compare two numbers with round-off errors considered.
    * Assume that the numbers are 18 decimals precision.
    */
    function assertEqDust(uint a_, uint b_) public {
        assertEqDust(a_, b_, eth);
    }

    /*
    * @dev Compare two numbers with round-off errors considered.
    * Assume that the numbers have the decimals of token.
    */
    function assertEqDust(uint a_, uint b_, address token) public {
        assertTrue(isEqualDust(a_, b_, token));
    }

    function isEqualDust(uint a_, uint b_) public view returns (bool) {
        return isEqualDust(a_, b_, eth);
    }

    function isEqualDust(uint a_, uint b_, address token) public view returns (bool) {
        uint diff = a_ - b_;
        require(dustSet[token], "Dust limit must be set to token.");
        uint dustT = dust[token];
        return diff < dustT || uint(-1) - diff < dustT;
    }

    function logMsgActualExpected(bytes32 logMsg, uint256 actual_, uint256 expected_, bool showActualExpected_) public {
        emit log_bytes32(logMsg);
        if(showActualExpected_ || showActualExpected) {
            emit log_bytes32("actual");
            emit LogTest(actual_);
            emit log_bytes32("expected");
            emit LogTest(expected_);
        }
    }

    function logMsgActualExpected(bytes32 logMsg, address actual_, address expected_, bool showActualExpected_) public {
        emit log_bytes32(logMsg);
        if(showActualExpected_ || showActualExpected) {
            emit log_bytes32("actual");
            emit LogTest(actual_);
            emit log_bytes32("expected");
            emit LogTest(expected_);
        }
    }

    function logMsgActualExpected(bytes32 logMsg, bytes32 actual_, bytes32 expected_, bool showActualExpected_) public {
        emit log_bytes32(logMsg);
        if(showActualExpected_ || showActualExpected) {
            emit log_bytes32("actual");
            emit LogTest(actual_);
            emit log_bytes32("expected");
            emit LogTest(expected_);
        }
    }

    function assertEqDustLog(bytes32 logMsg, uint256 actual_, uint256 expected_, address decimalToken) public {
        logMsgActualExpected(logMsg, actual_, expected_, !isEqualDust(actual_, expected_, decimalToken));
        assertEqDust(actual_, expected_, decimalToken);
    }

    function assertEqDustLog(bytes32 logMsg, uint256 actual_, uint256 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, !isEqualDust(actual_, expected_));
        assertEqDust(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, bytes32 actual_, bytes32 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertEqLog(bytes32 logMsg, uint256 actual_, uint256 expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, false);
        assertEq(actual_, expected_);
    }

    function assertNotEqualLog(bytes32 logMsg, address actual_, address expected_) public {
        logMsgActualExpected(logMsg, actual_, expected_, actual_ == expected_);
        assertTrue(actual_ != expected_);
    }
    function b(address a) public pure returns(bytes32) {
        return bytes32(uint(a));
    }

    function b(uint a) public pure returns(bytes32) {
        return bytes32(a);
    }

    function b(bool a) public pure returns(bytes32) {
        return a ? bytes32(uint(1)) : bytes32(uint(0));
    }


    function () external payable {
    }

    /*
    * @dev calculates multiple with decimals adjusted to match to 18 decimal precision to express base
    *      token Value
    */
    function wmulV(uint256 a, uint256 b_, address token) public view returns(uint256) {
        return wdiv(wmul(a, b_), decimals[token]);
    }

    /*
    * @dev calculates division with decimals adjusted to match to tokens precision
    */
    function wdivT(uint256 a, uint256 b_, address token) public view returns(uint256) {
        return wmul(wdiv(a, b_), decimals[token]);
    }

    function _createActors() internal {

        uint ourGas = gasleft();
        asm = new SimpleAssetManagement();
        emit LogTest("cerate SimpleAssetManagement");
        emit LogTest(ourGas - gasleft());

        guard = new DSGuard();
        asm.setAuthority(guard);

        user = address(new TrustedSASMTester(address(asm)));
        custodian = address(new TrustedSASMTester(address(asm)));
        custodian1 = address(new TrustedSASMTester(address(asm)));
        custodian2 = address(new TrustedSASMTester(address(asm)));
        exchange = address(new TrustedSASMTester(address(asm)));
    }

    function _createTokens() internal {

        dpt = address(new DSToken("DPT"));
        dai = address(new DSToken("DAI"));
        eth = address(0xee);
        eng = address(new DSToken("ENG"));

        cdc = address(new DSToken("CDC"));
        cdc1 = address(new DSToken("CDC1"));
        cdc2 = address(new DSToken("CDC2"));

        dcdc = address(new Dcdc("BR,IF,F,0.01", "DCDC", true));
        dcdc1 = address(new Dcdc("BR,SI3,E,0.04", "DCDC1", true));
        dcdc2 = address(new Dcdc("BR,SI1,J,1.50", "DCDC2", true));

        dpass = address(new Dpass());
        dpass1 = address(new Dpass());
        dpass2 = address(new Dpass());
    }

    function _setDust() internal {
        dust[dpt] = 10000;
        dust[cdc] = 10000;
        dust[eth] = 10000;
        dust[dai] = 10000;
        dust[eng] = 10;
        dust[dpass] = 10000;

        dustSet[dpt] = true;
        dustSet[cdc] = true;
        dustSet[eth] = true;
        dustSet[dai] = true;
        dustSet[eng] = true;
        dustSet[dpass] = true;
    }

    function _setGuardPermissions() internal {
        DSToken(cdc).setAuthority(guard);
        DSToken(cdc1).setAuthority(guard);
        DSToken(cdc2).setAuthority(guard);

        DSToken(dcdc).setAuthority(guard);
        DSToken(dcdc1).setAuthority(guard);
        DSToken(dcdc2).setAuthority(guard);

        Dpass(dpass).setAuthority(guard);
        Dpass(dpass1).setAuthority(guard);
        Dpass(dpass1).setAuthority(guard);

        guard.permit(address(this), address(asm), ANY);
        guard.permit(address(asm), dpass, ANY);
        guard.permit(address(asm), dpass1, ANY);
        guard.permit(address(asm), cdc, ANY);
        guard.permit(address(asm), cdc1, ANY);
        guard.permit(address(asm), cdc2, ANY);
        guard.permit(address(asm), dcdc, ANY);
        guard.permit(address(asm), dcdc1, ANY);
        guard.permit(address(asm), dcdc2, ANY);
        guard.permit(custodian, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("getRate(address)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("mint(address,address,uint256)")));

        guard.permit(custodian, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("mintDpass(address,address,bytes3,bytes16,bytes8,bytes20,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian, address(asm), bytes4(keccak256("setStateDpass(address,uint256[],bytes8)")));
        guard.permit(custodian, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian, dpass, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));
        guard.permit(custodian, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian, dpass1, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));
        guard.permit(custodian, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian, dpass2, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));

        guard.permit(custodian1, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("getRate(address)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("mint(address,address,uint256)")));

        guard.permit(custodian1, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("mintDpass(address,address,bytes3,bytes16,bytes8,bytes20,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("setStateDpass(address,uint256[],bytes8)")));
        guard.permit(custodian1, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian1, dpass, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));
        guard.permit(custodian1, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian1, dpass1, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));
        guard.permit(custodian1, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian1, dpass2, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));

        guard.permit(custodian2, address(asm), bytes4(keccak256("getRateNewest(address)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("getRate(address)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("mint(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("burnDcdc(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("mintDpass(address,address,bytes3,bytes16,bytes8,bytes20,uint24,bytes32,bytes8,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("mintDcdc(address,address,uint256)")));
        guard.permit(custodian2, address(asm), bytes4(keccak256("withdraw(address,uint256)")));
        guard.permit(custodian1, address(asm), bytes4(keccak256("setStateDpass(address,uint256[],bytes8)")));
        guard.permit(custodian2, dpass, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian2, dpass, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));
        guard.permit(custodian2, dpass1, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian2, dpass1, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));
        guard.permit(custodian2, dpass2, bytes4(keccak256("linkOldToNewToken(uint256,uint256)")));
        guard.permit(custodian2, dpass2, bytes4(keccak256("mintDiamondTo(address,address,bytes32,bytes32,bytes32,bytes32,uint24,bytes32,bytes8)")));

        guard.permit(exchange, address(asm), bytes4(keccak256("notifyTransferFrom(address,address,address,uint256)")));
        guard.permit(exchange, address(asm), bytes4(keccak256("burn(address,address,uint256)")));
        guard.permit(exchange, address(asm), bytes4(keccak256("mint(address,address,uint256)")));
    }

    function _mintInitialSupply() internal {
        DSToken(dpt).mint(SUPPLY);
        DSToken(dai).mint(SUPPLY);
        DSToken(eng).mint(SUPPLY);
    }

    function _setDecimals() internal {
        decimals[dpt] = 18;
        decimals[dai] = 18;
        decimals[eth] = 18;
        decimals[eng] = 8;

        decimals[cdc] = 18;
        decimals[cdc1] = 18;
        decimals[cdc2] = 18;

        decimals[dcdc] = 18;
        decimals[dcdc1] = 18;
        decimals[dcdc2] = 18;
    }

    function _setRates() internal {
        usdRate[dpt] = 2 ether;
        usdRate[dai] = 1 ether;
        usdRate[eth] = 7 ether;
        usdRate[eng] = 13 ether;

        usdRate[cdc] = 17 ether;
        usdRate[cdc1] = 19 ether;
        usdRate[cdc2] = 23 ether;

        usdRate[dcdc] = 29 ether;
        usdRate[dcdc1] = 31 ether;
        usdRate[dcdc2] = 37 ether;
    }

    function _setFeeds() internal {

        feed[dpt] = address(new TestFeedLike(usdRate[dpt], true));
        feed[cdc] = address(new TestFeedLike(usdRate[cdc], true));
        feed[eth] = address(new TestFeedLike(usdRate[eth], true));
        feed[dai] = address(new TestFeedLike(usdRate[dai], true));
        feed[eng] = address(new TestFeedLike(usdRate[eng], true));

        feed[cdc] = address(new TestFeedLike(usdRate[cdc], true));
        feed[cdc1] = address(new TestFeedLike(usdRate[cdc1], true));
        feed[cdc2] = address(new TestFeedLike(usdRate[cdc2], true));

        feed[dcdc] = address(new TestFeedLike(usdRate[dcdc], true));
        feed[dcdc1] = address(new TestFeedLike(usdRate[dcdc1], true));
        feed[dcdc2] = address(new TestFeedLike(usdRate[dcdc2], true));
    }

    function _setCustodianCap() internal {
       cap[custodian] = uint(-1);           // we set infinite cap on custodian
       cap[custodian1] = uint(-1);           // we set infinite cap on custodian
       cap[custodian2] = uint(-1);           // we set infinite cap on custodian
    }

    function _configAsm() internal {
        asm.setConfig("dex", b(exchange), "", "diamonds");
        asm.setConfig("decimals", b(dpt), b(decimals[dpt]), "diamonds");
        asm.setConfig("decimals", b(dai), b(decimals[dai]), "diamonds");
        asm.setConfig("decimals", b(eth), b(decimals[eth]), "diamonds");
        asm.setConfig("decimals", b(eng), b(decimals[eng]), "diamonds");

        asm.setConfig("decimals", b(cdc), b(decimals[cdc]), "diamonds");
        asm.setConfig("decimals", b(cdc1), b(decimals[cdc1]), "diamonds");
        asm.setConfig("decimals", b(cdc2), b(decimals[cdc2]), "diamonds");

        asm.setConfig("decimals", b(dcdc), b(decimals[dcdc]), "diamonds");
        asm.setConfig("decimals", b(dcdc1), b(decimals[dcdc1]), "diamonds");
        asm.setConfig("decimals", b(dcdc2), b(decimals[dcdc2]), "diamonds");

        asm.setConfig("priceFeed", b(dpt), b(feed[dpt]), "diamonds");
        asm.setConfig("priceFeed", b(cdc), b(feed[cdc]), "diamonds");
        asm.setConfig("priceFeed", b(eth), b(feed[eth]), "diamonds");
        asm.setConfig("priceFeed", b(dai), b(feed[dai]), "diamonds");
        asm.setConfig("priceFeed", b(eng), b(feed[eng]), "diamonds");

        asm.setConfig("priceFeed", b(cdc), b(feed[cdc]), "diamonds");
        asm.setConfig("priceFeed", b(cdc1), b(feed[cdc1]), "diamonds");
        asm.setConfig("priceFeed", b(cdc2), b(feed[cdc2]), "diamonds");

        asm.setConfig("priceFeed", b(dcdc), b(feed[dcdc]), "diamonds");
        asm.setConfig("priceFeed", b(dcdc1), b(feed[dcdc1]), "diamonds");
        asm.setConfig("priceFeed", b(dcdc2), b(feed[dcdc2]), "diamonds");

        asm.setConfig("custodians", b(custodian), b(true), "diamonds");
        asm.setConfig("custodians", b(custodian1), b(true), "diamonds");
        asm.setConfig("custodians", b(custodian2), b(true), "diamonds");

        asm.setCapCustV(custodian, cap[custodian]);
        asm.setCapCustV(custodian1, cap[custodian1]);
        asm.setCapCustV(custodian2, cap[custodian2]);


        asm.setConfig("payTokens", b(dpt), b(true), "diamonds");
        asm.setConfig("payTokens", b(dai), b(true), "diamonds");
        asm.setConfig("payTokens", b(eth), b(true), "diamonds");
        asm.setConfig("payTokens", b(eng), b(true), "diamonds");

        asm.setConfig("cdcs", b(cdc), b(true), "diamonds");
        asm.setConfig("cdcs", b(cdc1), b(true), "diamonds");
        asm.setConfig("cdcs", b(cdc2), b(true), "diamonds");

        asm.setConfig("dcdcs", b(dcdc), b(true), "diamonds");
        asm.setConfig("dcdcs", b(dcdc1), b(true), "diamonds");
        asm.setConfig("dcdcs", b(dcdc2), b(true), "diamonds");

        asm.setConfig("dpasses", b(dpass), b(true), "diamonds");
        asm.setConfig("dpasses", b(dpass1), b(true), "diamonds");
        asm.setConfig("dpasses", b(dpass2), b(true), "diamonds");
    }

}
//----------------------end-of-SimpleAssetManagementTest-----------------------------------------

contract TestFeedLike {
    bytes32 public rate;
    bool public feedValid;

    constructor(uint rate_, bool feedValid_) public {
        require(rate_ > 0, "TestFeedLike: Rate must be > 0");
        rate = bytes32(rate_);
        feedValid = feedValid_;
    }

    function peek() external view returns (bytes32, bool) {
        return (rate, feedValid);
    }

    function setRate(uint rate_) public {
        rate = bytes32(rate_);
    }

    function setValid(bool feedValid_) public {
        feedValid = feedValid_;
    }
}


contract TrustedDpassTester {
    Dpass public dpass;

    constructor(Dpass dpass_) public {
        dpass = dpass_;
    }

    function doSetSaleStatus(uint tokenId) public {
        dpass.setSaleState(tokenId);
    }

    function doRedeem(uint tokenId) public {
        dpass.redeem(tokenId);
    }

    function doSetState(bytes8 state, uint tokenId) public {
        dpass.setState(state, tokenId);
    }

    function doSetCustodian(uint tokenId, address newCustodian) public {
        dpass.setCustodian(tokenId, newCustodian);
    }

    function doSetAllowedCccc(bytes32 _cccc, bool allow) public {
        dpass.setCccc(_cccc, allow);
    }

    function doTransferFrom(address from, address to, uint256 tokenId) public {
        dpass.transferFrom(from, to, tokenId);
    }

    function doSafeTransferFrom(address from, address to, uint256 tokenId) public {
        dpass.safeTransferFrom(from, to, tokenId);
    }
}

contract TrustedSASMTester is Wallet {
    SimpleAssetManagement asm;
    uint buyPriceV;

    constructor(address payable asm_) public {
        asm = SimpleAssetManagement(asm_);
    }

    function setBuyPrice(uint buyPriceV_) public {
        buyPriceV = buyPriceV_;
    }

    function buyPrice(address token_, address owner_, uint256 tokenId_) external view returns (uint) {
        token_;
        owner_;
        tokenId_;
        return buyPriceV;
    }

    function doSetConfig(bytes32 what_, bytes32 value_, bytes32 value1_, bytes32 value2_) public {
        asm.setConfig(what_, value_, value1_, value2_);
    }

    function doSetBasePrice(address token, uint256 tokenId, uint256 price) public {
        asm.setBasePrice(token, tokenId, price);
    }

    function doSetCdcV(address cdc) public {
        asm.setCdcV(cdc);
    }

    function doSetStateDpass(address token, uint tokenId, bytes8 state) public {
        asm.setStateDpass(token, tokenId, state);
    }
/*
    function doSetStateDpass(address token, uint[] memory tokenIds, bytes8 state) public {
        asm.setStateDpass(token, tokenIds, state);
    }*/

    function doSetTotalDcdcV(address dcdc) public {
        asm.setTotalDcdcV(dcdc);
    }

    function doSetDcdcV(address dcdc, address custodian) public {
        asm.setDcdcV(dcdc, custodian);
    }

    function doNotifyTransferFrom(address token, address src, address dst, uint256 amtOrId) public {
        asm.notifyTransferFrom(token, src, dst, amtOrId);
    }

    function doBurn(address token, uint256 amt) public {
        asm.burn(token, amt);
    }

    function doMint(address token, address dst, uint256 amt) public {
        asm.mint(token, dst, amt);
    }

    function doMintDpass(
        address token_,
        address custodian_,
        bytes3 issuer_,
        bytes16 report_,
        bytes8 state_,
        bytes20 cccc_,
        uint24 carat_,
        bytes32 attributesHash_,
        bytes8 currentHashingAlgorithm_,
        uint price_
    ) public returns (uint) {

        return asm.mintDpass(
            token_,
            custodian_,
            issuer_,
            report_,
            state_,
            cccc_,
            carat_,
            attributesHash_,
            currentHashingAlgorithm_,
            price_);
    }

    function doMintDcdc(address token, address dst, uint256 amt) public {
        asm.mintDcdc(token, dst, amt);
    }

    function doBurnDcdc(address token, address dst, uint256 amt) public {
        asm.burnDcdc(token, dst, amt);
    }

    function doWithdraw(address token, uint256 amt) public {
        asm.withdraw(token, amt);
    }

    function doSetCollateralDpass(uint positiveV, uint negativeV, address custodian) public {
        asm.setCollateralDpass(positiveV, negativeV, custodian);
    }

    function doSetCollateralDcdc(uint positiveV, uint negativeV, address custodian) public {
        asm.setCollateralDcdc(positiveV, negativeV, custodian);
    }

    function doApprove(address token, address dst, uint256 amt) public {
        DSToken(token).approve(dst, amt);
    }

    function doSendToken(address token, address src, address payable dst, uint256 amt) public {
        sendToken(token, src, dst, amt);
    }

    function doSendDpassToken(address token, address src, address payable dst, uint256 id_) public {
        Dpass(token).transferFrom(src, dst, id_);
    }

    function () external payable {
    }
}
