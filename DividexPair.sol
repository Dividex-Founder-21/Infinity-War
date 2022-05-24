pragma solidity = 0.8.14;

import './interfaces/IDividexPair.sol';

contract DividexPair {

    address public factory;
    address public token0;
    address public token1;
    uint32 public baseFee;

    constructor() public{}

function initialize(address _token0, address _token1, uint32 _baseFee) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
        baseFee = _baseFee;
    }

}