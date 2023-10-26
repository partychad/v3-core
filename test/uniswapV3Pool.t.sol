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


contract UniswapV3PoolTest is Test, IUniswapV3PoolDeployer, IUniswapV3MintCallback {
    ERC20Mintable customToken0;
    ERC20Mintable customToken1;
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
        customToken0 = new ERC20Mintable("Ether", "ETH", 18);
        customToken1 = new ERC20Mintable("USDC", "USDC", 18);
        customToken0.mint(address(this), 10 ether);
        customToken1.mint(address(this), 1000 ether);
        feeAmountTickSpacing[500] = 10;
        feeAmountTickSpacing[3000] = 60;
        feeAmountTickSpacing[10000] = 200;
        factory = new UniswapV3Factory();

    }

    function testInitialize() public {
        pool = UniswapV3Pool(
            factory.createPool(address(customToken0), address(customToken1), 3000)
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
        
        uint24 fee = 500;
        int24 tickSpacing = feeAmountTickSpacing[fee]; 

        require(tickSpacing != 0);

        pool = UniswapV3Pool(deploy(vm.addr(1), address(customToken0), address(customToken1),fee,tickSpacing));
        uint160 sqrtPriceX96 =  1872278214570549032811324048980506;
        pool.initialize(sqrtPriceX96);
        (uint160 sqrtPrice,,,,,uint8 feeProtocol,bool unlocked) = pool.slot0();       
        emit log_uint(sqrtPrice);
        bytes memory data = abi.encode(address(this));
        customToken0.approve(address(pool),1000000 ether);
        customToken1.approve(address(pool),1000000 ether);
        // pool.mint(address(this),84222,86129,1517882343751509868544,data);
        emit log_address(address(this));
        emit log_address(address(pool));
        pool.createLimitOrder(address(this),100,10000000);
        assertTrue(true);
    }


    function getSlot0Data(UniswapV3Pool _pool) external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    ) {
        return _pool.slot0();
    }

     function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address newPool) {
        parameters = Parameters({factory: factory, token0: address(token0), token1: address(token1), fee: fee, tickSpacing: tickSpacing});
        newPool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) public {
                if (5 != 3) revert LOK();

        emit log_address(IUniswapV3Pool(pool).token0());
        emit log_address(IUniswapV3Pool(pool).token1());

        if (amount0Owed > 0)
            ERC20Mintable(IUniswapV3Pool(msg.sender).token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0)
            ERC20Mintable(IUniswapV3Pool(msg.sender).token1()).transfer(msg.sender, amount1Owed);
    }


    function sqrtP(uint256 price) internal pure returns (uint160) {
        return
            uint160(
                int160(
                    ABDKMath64x64.sqrt(int128(int256(price << 64))) <<
                        (FixedPoint96.RESOLUTION - 64)
                )
            );
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

     function deployPool(
        UniswapV3Factory factory,
        address token0,
        address token1,
        uint24 fee,
        uint256 currentPrice
    ) internal returns (UniswapV3Pool pool) {
        pool = UniswapV3Pool(factory.createPool(token0, token1, fee));
        pool.initialize(sqrtP(currentPrice));
    }
}
