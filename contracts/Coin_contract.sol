// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract StableCoin 
{
    // --- Auth ---
    mapping (address => uint) public wards;
    modifier auth 
    {
        require(wards[msg.sender] == 1, "Not-authorized");
        _;
    }

    string public constant name = "Kryton";
    string public constant symbol = "KR";
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
        balanceOf[usr] = sub(balanceOf[usr], wad);
        totalSupply = sub(totalSupply, wad);
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
    
    // Price feed
    AggregatorV3Interface internal priceFeed;
    uint USDinCZK = 23;
    // Note: Price of USD in CZK is hardcoded, which is bad. But aim for this project was to create stablecoin pegged to CZK.
    // Since there are no Oracles providing price feeds in CZK, I had to use USD ones and transform it to CZK. 
    // I could make this variable configurable by contract deployer (me), but I would then represent third party risk, as 
    // everyone would need to trust me I will not change it in malicious way to confuse the contract. 
    // I decided that "least bad" solution is to make it hardcoded and uneditable by anyone. 

    constructor() 
    {
        wards[msg.sender] = 1;
        coinContract = new StableCoin();
        
        // Available price feeds:

        /* Network: Arbitrum
        * Aggregator: ETH/USD
        * Address: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612  */

        /* Network: Optimism
        * Aggregator: ETH/USD
        * Address: 0x13e3Ee699D1909E989722E753853AE30b17e08c5  */
        
        priceFeed = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);
    }

    function depositETH(uint256 amount) payable public
    {
        require(msg.value == amount);
    }

    // WARNING: following function is there only for development purposes. It shall not be present in finally deployed contract.
    // If you see this function, do not use this contract.
    // This function is literally giving me right to access whole collateral vault.
    function withdrawETH() public auth 
    {
        address payable to = payable(msg.sender);
        to.transfer(getVaultBalance());
    }
    
    function getVaultBalance() public view returns (uint) 
    {
        return address(this).balance;
    }

    // get Ethereum price from Chainlink oracle
    function getEthPriceCZK() public view returns (uint)
    {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        uint uprice = uint(price);

        // convert USD to CZK
        return (uprice * USDinCZK) / 100000000;
    }

    // minting stablecoin
    function buyStablecoinForETH(uint256 ETH_amount) payable public
    {
        require(msg.value == ETH_amount);

        // calculate right amount of stablecoin to mint
        uint amount = ( ETH_amount * getEthPriceCZK() ) / 1000000000000000000;
        
        // mint the stablecoin
        coinContract.mint(msg.sender, amount);
    }

    // burning stablecoin
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