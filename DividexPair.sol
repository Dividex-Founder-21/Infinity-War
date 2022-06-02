pragma solidity = 0.8.14;

import './interfaces/IDividexPair.sol';
import './interfaces/IDividexERC20.sol';
import './interfaces/IDividexCallee.sol';
import './interfaces/IERC20.sol';
import './DividexERC20.sol';
import './libraries/Math.sol';

contract DividexPair is IDividexPair, IDividexERC20 {

    uint public constant MINIMUM_LIQUIDITY = 10**3;
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
    uint112 private rangeNumerator; //new variable for range percentage
    uint112 private rangeDenominator; //new variable for range percentage
    uint112 private range0; //new variable for Dividex calculations (range coin count)
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
        balanceModified0 = balance0*(10**9);
        balanceModified1 = balance1*(10**9);
        slipDif0 = uint112(balanceModified0) > (liability0 - range0) ? uint112(balanceModified0) - (liability0 - range0) : 0;
        slipDif1 = uint112(balanceModified1) > (liability1 - range1) ? uint112(balanceModified1) - (liability1 - range1) : 0;
    }

    function _updateLiquidity(uint liquidity0, uint liquidity1, uint balance0, uint balance1 ) private {
        liability0 += uint112(liquidity0)*(10**9);
        liability1 += uint112(liquidity1)*(10**9);
        range0 = (rangeNumerator*(10**9)/rangeDenominator)*liability0;
        range1 = (rangeNumerator*(10**9)/rangeDenominator)*liability1;
        _updateSlipDif(balance0, balance1, range0, range1, liability0, liability1);
    } //range will need to be converted in interface

        // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity0, uint liquidity1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        (uint112 _slipDif0, uint112 _slipDif1, uint112 _range0, uint112 _range1,
        uint112 _liability0, uint112 _liability1) = getPoolVariables(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        //uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update
        
        //token 0 mint determination
        if (_liability0 == 0) {
            liquidity0 = amount0 - MINIMUM_LIQUIDITY;
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity0 = amount0;
        }
        require(liquidity0 > 0 || liquidity1, 'Dividex: INSUFFICIENT_LIQUIDITY_MINTED');

        //token 1 mint determination
        if (_liability1 == 0) {
            liquidity1 = amount1 - MINIMUM_LIQUIDITY;
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity1 = amount1;
        }
        require(liquidity0 > 0 || liquidity1, 'Dividex: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity0);
        _mint(to, liquidity1);
        //why do we not reupdate balances here like in burn
        _updateLiquidity(liquidity0, liquidity1, balance0, balance1); //update slipdif called in this function
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, liqudity0, liquidity1);
    }

    //will have to make significant changes by using ERC 1155


    //need to create burn function that can burn based on scenario (deficit, balance, and surplus)
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        (uint112 _slipDif0, uint112 _slipDif1, uint112 _range0, uint112 _range1,
        uint112 _liability0, uint112 _liability1) = getPoolVariables(); //gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = 10**9*IERC20(_token0).balanceOf(address(this));
        uint balance1 = 10**9*IERC20(_token1).balanceOf(address(this));

        //create if statements for liquidity
        liquidity0 = balanceOf[address(this)]; //should work because liquidity0 made in mint which is external contract
        liquidity1 = balanceOf[address(this)]; //should work because liquidity1 made in mint which is external contract

        if (balance0 <= _liability0 && balance1 <= _liability1) { //perfect balance or deficit (without surplus)
         // using balances ensures pro-rata distribution
            amount0 = liquidity0*(balance0) / _liability0;
            amount1 = liquidity1*(balance1) / _liability1; 
        }
        else if (balance0 >= _liability0 && balance1 >= _liability1){ //perfect balance or surplus (without deficit)
            amount0 = liquidity0*(balance0) / _liability0;
            amount1 = liquidity1*(balance1) / _liability1;
        }
        //only if one is in surplus and the other is in deficit
        else if (balance0 < _liability0) //token0 in deficit
        {
            amount0 = liquidity0*(balance0) / _liability0;
            amount1 = liquidity1*(balance1) / _liability1 + liquidity0*(balance1-liability1) / _liability0;
        }
        else { //token1 in deficit
            amount0 = liquidity0*(balance0) / _liability0 + liquidity1*(balance0-liability0) / _liability1;
            amount1 = liquidity1*(balance1) / _liability1;
        }

        require(amount0 > 0 || amount1 > 0, 'Dividex: INSUFFICIENT_LIQUIDITY_BURNED'); //change to or statement
        _burn(address(this), liquidity0);
        _burn(address(this), liquidity1);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _updateLiquidity(liquidity0, liquidity1, balance0, balance1); //update slipdif called in this function
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
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
        require(balance0*balance1*(10**18) >= limit, 'Dividex: K Limit'); //to the 18th = 9+9 from updateSlipDif
        }

        _updateSlipDif(balance0, balance1, _range0, _range1, _liability0, _liability1);
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

        function skim(address to) external lock { //look into whether we need this
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    //is fee calculated on website or on swap smart contract
    //calculations could be done on website instead of smart contract (maybe) (more research required)
    function feeDist(uint fee, bool coin) external lock returns (uint lpReward, uint divReward) {//will be separate for each coin
        (uint112 _slipDif0, uint112 _slipDif1, uint112 _range0, uint112 _range1,
        uint112 _liability0, uint112 _liability1) = getPoolVariables();
        uint slipDif;
        uint range;
        if (coin = true){
            slipDif = _slipDif0;
            range = _range0;
        }
        else{
            slipDif = _slipDif1;
            range = _range1;
        }
        require(fee > 0, 'Dividex: Invalid fee'); //must have earned some fee
        uint base = (10**9)/2;
        uint lpPerc = base + (10**9)*Math.sqrt(Math.min(Math.max(slipDif/Range),0)); //check to make sure each math operation doesn't truncate decimals
        uint divPerc = 10**9 - lpPerc;
        require(lpPerc + divPerc = 10**9, 'Dividex: Invalid calculation'); //must check out and add to 100%
        lpReward = lpPerc * fee;
        divReward = divPerc * fee;
        //must emit event here - build function in interface - maybe not

    }

    function feeDidurse(address to, uint amountOut0, uint amountOut1, uint totalFeesOwed0, uint totalFeesOwed1) external lock {
        require(amountOut0 > 0 || amountOut1 > 0, 'Invalid fee amount : Dividex');
        require(amountOut0 < totalFeesOwed0 && amountOut1 < totalFeesOwed1, 'Fee more than owed: Dividex'); // check less than what is actually owed - will come in from website
        address _token0 = token0;
        address _token1 = token1; //are fees stored in balance? Where are fees stored?

        //do we need balance? - unsure
        //balance0 = IERC20(_token0).balanceOf(address(this));
        //balance1 = IERC20(_token1).balanceOf(address(this));
        //require(amount0Out < balance0 && amount1Out < balance1, 'Fee more than total balance: Dividex');

        //_feeDisburse(address(this), amount0, liquidity1); //look into this, I am a little confused
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        emit feeDisburse(msg.sender, amount0Out, amount1Out, to);

    }

        // force reserves to match balances
        function sync() external lock {//look into whether we need this
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}