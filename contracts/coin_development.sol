// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


contract StableCoin 
{
    // --- Auth ---
    mapping (address => uint) public wards;
    modifier auth 
    {
        require(wards[msg.sender] == 1, "Not-authorized");
        _;
    }

    string public constant name = "DotaCoin";
    string public constant symbol = "DC";
    string public constant version  = "1";
    uint8 public constant decimals = 0;
    uint256 public totalSupply;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping (address => uint)) public allowance;
    mapping (address => uint) public nonces;

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) 
    {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) 
    {
        require((z = x - y) <= x);
    }

    constructor() 
    {
        wards[msg.sender] = 1;
        totalSupply = 0;

        uint wad = 100;
        balanceOf[msg.sender] = add(balanceOf[msg.sender], wad);
        totalSupply = add(totalSupply, wad);
        emit Transfer(address(0), msg.sender, wad);
    }

    function transfer(address receiver, uint numTokens) external returns (bool) 
    {
        return transferFrom(msg.sender, receiver, numTokens);
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) 
    {
        require(numTokens <= balanceOf[owner], "insufficient-balance");
        if (owner != msg.sender)
        {
            require(numTokens <= allowance[owner][msg.sender], "insufficient-allowance");
            allowance[owner][msg.sender] = sub(allowance[owner][msg.sender], numTokens);
        }
        balanceOf[owner] = sub( balanceOf[owner], numTokens);
        balanceOf[buyer] = add( balanceOf[buyer], numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }

    function approve(address delegate, uint numTokens) public returns (bool) 
    {
        allowance[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    // --- Coin control ---
    function mint(address usr, uint wad) external auth 
    {
        balanceOf[usr] = add(balanceOf[usr], wad);
        totalSupply = add(totalSupply, wad);
        emit Transfer(address(0), usr, wad);
    }
    function burn(address usr, uint wad) external auth 
    {
        require(balanceOf[usr] >= wad, "insufficient-balance");
        //require(allowed[usr][msg.sender] >= wad, "insufficient-allowance");
        //allowed[usr][msg.sender] = sub(allowed[usr][msg.sender], wad);
        balanceOf[usr] = sub(balanceOf[usr], wad);
        totalSupply = sub(totalSupply, wad);
        emit Transfer(usr, address(0), wad);
    }
}

