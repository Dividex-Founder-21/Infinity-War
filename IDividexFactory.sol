pragma solidity >=0.8.14;

interface IDividexFactory {
    event PairCreated(address indexed token0, address indexed token1, uint32 baseFee, address pair, uint);

    function getPair(address tokenA, address tokenB, uint32 baseFee) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB, uint32 baseFee) external returns (address pair);

}
