pragma solidity = 0.8.14;

import './interfaces/IDividexPair.sol';
import './interfaces/IDividexCallee.sol';
import './interfaces/IERC20.sol';

contract DividexPair is IDividexPair {

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;
    uint32 public baseFee;

    uint112 private reserve0;           // uses single storage slot, accessible via getPoolVariables
    uint112 private reserve1;           // uses single storage slot, accessible via getPoolVariables
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getPoolVariables
    uint112 private slipDif0; //new variable for Dividex calculations
    uint112 private slipDif1; //new variable for Dividex calculations
    uint112 private range0; //new variable for Dividex calculations
    uint112 private range1; //new variable for Dividex calculations
    uint112 private liability0; //new variable for Dividex calculations
    uint112 private liability1; //new variable for Dividex calculations

    constructor() public {
        factory = msg.sender;
    }

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Dividex: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function getPoolVariables() public view returns (uint112 _slipDif0, uint112 _slipDif1, uint112 _range0, uint112 _range1,
     uint112 _liability0, uint112 _liability1) {
        _slipDif0 = slipDif0; //added variable to this function
        _slipDif1 = slipDif1; //added variable to this function
        _range0 = range0; //added variable to this function
        _range1 = range1; //added variable to this function
        _liability0 = liability0; //added variable to this function
        _liability1 = liability1; //added variable to this function
    }

function initialize(address _token0, address _token1, uint32 _baseFee) external {
        require(msg.sender == factory, 'Dividex: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
        baseFee = _baseFee;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Dividex: TRANSFER_FAILED');
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= 2**112-1 && balance1 <= 2**112-1, 'Dividex: OVERFLOW');
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function _updateSlipDif(uint balance0, uint balance1, uint112 _range0, uint112 _range1,
     uint112 _liability0, uint112 _liability1) private {
        slipDif0 = uint112(balance0) > (liability0 - range0) ? uint112(balance0) - (liability0 - range0) : 0;
        slipDif1 = uint112(balance1) > (liability1 - range1) ? uint112(balance1) - (liability1 - range1) : 0;
    }



function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'Dividex: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Dividex: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'Dividex: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IDividexCallee(to).dividexCall(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'Dividex: INSUFFICIENT_INPUT_AMOUNT');
        (uint112 _slipDif0, uint112 _slipDif1, uint112 _range0, uint112 _range1,
        uint112 _liability0, uint112 _liability1) = getPoolVariables();
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        
        uint limit0 = uint(_liability0 - _range0);
        uint limit1 = uint(_liability1 -_range1);
        uint limit = limit0*limit1;
        require(balance0*balance1 >= limit, 'Dividex: K Limit');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        _updateSlipDif(balance0, balance1, _range0, _range1, _liability0, _liability1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

        function skim(address to) external lock { //look into whether we need this
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

        // force reserves to match balances
    function sync() external lock {//look into whether we need this
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}