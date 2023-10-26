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
import "./UniswapV3Pool.Utils.t.sol";

contract UniswapV3PoolTest is Test, IUniswapV3PoolDeployer, IUniswapV3MintCallback, TestUtils, UniswapV3PoolUtils {
    ERC20Mintable WETH;
    ERC20Mintable USDC;
    UniswapV3Pool pool;
    UniswapV3Factory factory;
    uint24 fee;
    mapping(uint24 => uint24) public  feeAmountTickSpacing;
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
        fee = 3000;
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
        

        pool = deployPool(
            factory,
            address(WETH),
            address(USDC),
            fee,
            5000
        );
        WETH.approve(address(this),type(uint256).max);
        USDC.approve(address(this),type(uint256).max);

         bytes memory extra = encodeExtra(
                address(WETH),
                address(USDC),
                address(this)
            );
        pool.mint(address(this),360,480,1517882343751509868544,extra);
        // pool.createLimitOrder(address(this),120,10000000);


    }
    function testMintInRange() public {
        (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        ) = setupPool(
                PoolParams({
                    balances: [uint256(1 ether), 5000 ether],
                    currentPrice: 5000,
                    liquidity: liquidityRanges(
                        liquidityRange(4545, 4545 + feeAmountTickSpacing[fee], 1 ether, 5000 ether, 5000)
                    ),
                    transferInMintCallback: true,
                    transferInSwapCallback: true,
                    mintLiqudity: true
                })
            );

        (uint256 expectedAmount0, uint256 expectedAmount1) = (
            0.987078348444137445 ether,
            5000 ether
        );

        assertEq(
            poolBalance0,
            expectedAmount0,
            "incorrect weth deposited amount"
        );
        assertEq(
            poolBalance1,
            expectedAmount1,
            "incorrect usdc deposited amount"
        );

    }


    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
            
            if (amount0 > 0)
            ERC20Mintable(WETH).transferFrom(address(this), msg.sender, amount0);
            if (amount1 > 0)
            ERC20Mintable(USDC).transferFrom(address(this), msg.sender, amount1);

    }


    function setupPool(PoolParams memory params)
        internal
        returns (
            LiquidityRange[] memory liquidity,
            uint256 poolBalance0,
            uint256 poolBalance1
        )
    {
        WETH.mint(address(this), params.balances[0]);
        USDC.mint(address(this), params.balances[1]);

        pool = deployPool(
            factory,
            address(WETH),
            address(USDC),
            fee,
            params.currentPrice
        );

        if (params.mintLiqudity) {
            WETH.approve(address(this), params.balances[0]);
            USDC.approve(address(this), params.balances[1]);

            uint256 poolBalance0Tmp;
            uint256 poolBalance1Tmp;
            for (uint256 i = 0; i < params.liquidity.length; i++) {
                (poolBalance0Tmp, poolBalance1Tmp) = pool.createLimitOrder(
                    address(this),
                    params.liquidity[i].lowerTick,
                    params.liquidity[i].amount
                );
                poolBalance0 += poolBalance0Tmp;
                poolBalance1 += poolBalance1Tmp;
            }
        }

        liquidity = params.liquidity;
    }

}
