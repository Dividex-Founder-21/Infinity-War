pragma solidity = 0.8.14;

import './interfaces/IDividexFactory.sol';
import './DividexPair.sol';
//will need to import interfaces as needed

contract DividexFactory is IDividexFactory{ //will include "is IDividexFactory once the interface function is set up

    uint public maxFee;

    mapping(address => mapping(address => mapping(uint32 => address))) public getPair; //needs to be modified to include baseFee
    address[] public allPairs; //array with all addresses of pairs

    constructor(uint _maxFee) public {
        maxFee = _maxFee;
    } //will be modified later when we consider possible state variable

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    } //returns number of pairs as allPairs is an array

    function setMaxFee(uint newFee) public {
        maxFee = newFee;
    }

    //baseFee set up as int that can range from 0 to 10000 (exclusive) so lowest fee is 0.01% and highest is 99.99%
    function createPair(address tokenA, address tokenB, uint32 baseFee) external returns (address pair) {//base fee added
        uint32 _baseFee = baseFee; //save gas
        require(_baseFee > 0 && _baseFee < maxFee, 'Dividex: Fee Invalid');
        require(tokenA != tokenB, 'Dividex: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Dividex: ZERO_ADDRESS');
        require(getPair[token0][token1][_baseFee] == address(0), 'Dividex: PAIR_EXISTS'); // single check is sufficient
        IDividexPair(pair).initialize(token0, token1, _baseFee);
        getPair[token0][token1][_baseFee] = pair;
        getPair[token1][token0][_baseFee] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, _baseFee, pair, allPairs.length);
    }

}