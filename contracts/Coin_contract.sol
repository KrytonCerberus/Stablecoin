// SPDX-License-Identifier: GPL-3.0

// how one contract can deploy another one
// https://stackoverflow.com/questions/70209083/can-smart-contracts-deploy-other-smart-contracts
// https://ethereum-blockchain-developer.com/020-escrow-smart-contract/03-withdraw-ether-smart-contract/
// https://ethereum.stackexchange.com/questions/46107/how-do-you-send-ether-as-a-function-to-a-contract-using-remix



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

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    string public constant name = "SomeCoin";
    string public constant symbol = "SC";
    uint8 public constant decimals = 0;
    uint256 totalSupply_;

    mapping(address => uint) balances;
    mapping(address => mapping (address => uint)) allowed;

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
        totalSupply_ = 0;
    }

    function totalSupply() public view returns (uint256) 
    {
      return totalSupply_;
    }

    function balanceOf(address tokenOwner) public view returns (uint) 
    {
        return balances[tokenOwner];
    }

    function transfer(address receiver, uint numTokens) public returns (bool) 
    {
        return transferFrom(msg.sender, receiver, numTokens);
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) 
    {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);
        allowed[owner][msg.sender] = sub(allowed[owner][msg.sender], numTokens);
        balances[owner] = sub( balances[owner], numTokens);
        balances[buyer] = add( balances[buyer], numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }

    function approve(address delegate, uint numTokens) public returns (bool) 
    {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function allowance(address owner, address delegate) public view returns (uint) 
    {
        return allowed[owner][delegate];
    }

    // --- Coin control ---
    function mint(address usr, uint wad) external auth 
    {
        balances[usr] = add(balances[usr], wad);
        totalSupply_ = add(totalSupply_, wad);
        emit Transfer(address(0), usr, wad);
    }
    function burn(address usr, uint wad) external auth 
    {
        require(balances[usr] >= wad, "insufficient-balance");
        //require(allowed[usr][msg.sender] >= wad, "insufficient-allowance");
        //allowed[usr][msg.sender] = sub(allowed[usr][msg.sender], wad);
        balances[usr] = sub(balances[usr], wad);
        totalSupply_ = sub(totalSupply_, wad);
        emit Transfer(usr, address(0), wad);
    }
}



contract Organization 
{
    // --- Auth ---
    mapping (address => uint) public wards;
    modifier auth 
    {
        require(wards[msg.sender] == 1, "Not-authorized");
        _;
    }
    
    StableCoin private coinContract;

    constructor() 
    {
        wards[msg.sender] = 1;
        coinContract = new StableCoin();
    }

    function depositETH(uint256 amount) payable public
    {
        require(msg.value == amount);
    }

    function withdrawETH() public auth 
    {
        address payable to = payable(msg.sender);
        to.transfer(getVaultBalance());
    }
    
    function getVaultBalance() public view returns (uint) 
    {
        return address(this).balance;
    }

    // minting and burning of stablecoin
    function getEthPriceCZK() private view returns (uint)
    {
        return 30000;
    }

    function buyStablecoinForETH(uint256 ETH_amount) payable public
    {
        require(msg.value == ETH_amount);

        // calculate right amount of stablecoin to mint
        uint amount = ( ETH_amount * getEthPriceCZK() ) / 1000000000000000000;
        
        // mint the stablecoin
        coinContract.mint(msg.sender, amount);
    }

    function sellStablecoinForETH(uint256 stable_tokens) public  
    {
        // check is user has amount of stablecoin he wants to sell
        require(coinContract.balanceOf(msg.sender) >= stable_tokens, "insufficient-balance");
        
        // sent ETH to the user
        uint ethToSend = ( stable_tokens * 1000000000000000000) / getEthPriceCZK();
        require(ethToSend <= getVaultBalance(), "Collateral vault was liquidated !");
        address payable to = payable(msg.sender);
        to.transfer(ethToSend);

        // burn user's stablecoin
        coinContract.burn(msg.sender, stable_tokens);
    }
}