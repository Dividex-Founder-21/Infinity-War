pragma solidity >=0.8.14;

interface IDividexCallee {
    function dividexCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
