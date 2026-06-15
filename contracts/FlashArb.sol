```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IPoolAave {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256);
}

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FlashArb is IFlashLoanSimpleReceiver {

    address public owner;

    address constant AAVE_POOL      = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address constant UNISWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant AERO_ROUTER    = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY   = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant WETH           = 0x4200000000000000000000000000000000000006;
    address constant USDC           = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function executeArb(uint256 amount, bool uniFirst) external onlyOwner {
        bytes memory params = abi.encode(uniFirst);
        IPoolAave(AAVE_POOL).flashLoanSimple(
            address(this),
            USDC,
            amount,
            params,
            0
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == AAVE_POOL, "Caller not Aave");
        bool uniFirst = abi.decode(params, (bool));
        uint256 amountOwed = amount + premium;

        if (uniFirst) {
            uint256 wethOut = _swapUniswap(USDC, WETH, 500, amount);
            _swapAero(WETH, USDC, wethOut);
        } else {
            uint256 wethOut = _swapAero(USDC, WETH, amount);
            _swapUniswap(WETH, USDC, 500, wethOut);
        }

        IERC20(asset).approve(AAVE_POOL, amountOwed);
        return true;
    }

    function _swapUniswap(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) internal returns (uint256) {
        IERC20(tokenIn).approve(UNISWAP_ROUTER, amountIn);
        ISwapRouter.ExactInputSingleParams memory p = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        return ISwapRouter(UNISWAP_ROUTER).exactInputSingle(p);
    }

    function _swapAero(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256) {
        IERC20(tokenIn).approve(AERO_ROUTER, amountIn);
        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({
            from: tokenIn,
            to: tokenOut,
            stable: false,
            factory: AERO_FACTORY
        });
        uint256[] memory amounts = IAeroRouter(AERO_ROUTER).swapExactTokensForTokens(
            amountIn,
            0,
            routes,
            address(this),
            block.timestamp + 300
        );
        return amounts[amounts.length - 1];
    }

    function withdraw() external onlyOwner {
        uint256 bal = IERC20(USDC).balanceOf(address(this));
        if (bal > 0) IERC20(USDC).transfer(owner, bal);
        uint256 ethBal = address(this).balance;
        if (ethBal > 0) payable(owner).transfer(ethBal);
    }

    receive() external payable {}
}
```
