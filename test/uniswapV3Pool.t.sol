// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "./ERC20Mintable.sol";
import "../src/UniswapV3Pool.sol";
import "forge-std/Test.sol";
import {IUniswapV3PoolDeployer} from '../src/interfaces/IUniswapV3PoolDeployer.sol';
import {UniswapV3Pool} from '../src/UniswapV3Pool.sol';
import "../src/UniswapV3Factory.sol";
import "../src/libraries/FixedPoint96.sol";
import "abdk-math/ABDKMath64x64.sol";
import "./TestUtils.sol";


contract UniswapV3PoolTest is Test, IUniswapV3PoolDeployer, IUniswapV3MintCallback, TestUtils {
    ERC20Mintable WETH;
    ERC20Mintable USDC;
    UniswapV3Pool pool;
    UniswapV3Factory factory;

    mapping(uint24 => int24) public  feeAmountTickSpacing;
    error LOK();

     struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    Parameters public override parameters;

    function setUp() public {
        WETH = new ERC20Mintable("Ether", "ETH", 18);
        USDC = new ERC20Mintable("USDC", "USDC", 18);
        WETH.mint(address(this), type(uint256).max);
        USDC.mint(address(this), type(uint256).max);
        
        feeAmountTickSpacing[500] = 10;
        feeAmountTickSpacing[3000] = 60;
        feeAmountTickSpacing[10000] = 200;
        factory = new UniswapV3Factory();

    }

    function testInitialize() public {
        pool = UniswapV3Pool(
            factory.createPool(address(WETH), address(USDC), 3000)
        );

        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        ) = pool.slot0();
        assertEq(sqrtPriceX96, 0, "invalid sqrtPriceX96");
        assertEq(tick, 0, "invalid tick");
        assertEq(observationIndex, 0, "invalid observation index");
        assertEq(observationCardinality, 0, "invalid observation cardinality");
        assertEq(
            observationCardinalityNext,
            0,
            "invalid next observation cardinality"
        );

        pool.initialize(sqrtP(31337));

        (
            sqrtPriceX96,
            tick,
            observationIndex,
            observationCardinality,
            observationCardinalityNext,
            feeProtocol,
            unlocked
        ) = pool.slot0();
        assertEq(
            sqrtPriceX96,
            14025175117687921942002399182848,
            "invalid sqrtPriceX96"
        );
        assertEq(tick, 103530, "invalid tick");
        assertEq(observationIndex, 0, "invalid observation index");
        assertEq(observationCardinality, 1, "invalid observation cardinality");
        assertEq(
            observationCardinalityNext,
            1,
            "invalid next observation cardinality"
        );

        vm.expectRevert();
        pool.initialize(sqrtP(42));
    }

   

    function testExample() public {
        emit log_named_address("msg.sender", msg.sender);
        emit log_named_address("this", address(this));
        uint24 fee = 500;
        int24 tickSpacing = feeAmountTickSpacing[fee]; 

        require(tickSpacing != 0);

        pool = deployPool(
            factory,
            address(WETH),
            address(USDC),
            3000,
            5000
        );
        WETH.approve(address(this),type(uint256).max);
        USDC.approve(address(this),type(uint256).max);

         bytes memory extra = encodeExtra(
                address(WETH),
                address(USDC),
                address(this)
            );
        // pool.createLimitOrder(address(this),120,10000000);


    }



    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
            CallbackData memory extra = abi.decode(
                data,
                (CallbackData)
            );

            ERC20Mintable(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            ERC20Mintable(extra.token1).transferFrom(extra.payer, msg.sender, amount1);

    }

}
