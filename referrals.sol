// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Wallet.sol";
import "./pricefeed1.sol";
import "./ERC777.sol";

abstract contract Referral is Wallet, PriceConsumerV3, ERC777 {

    bool private active;

    int256 public max_levels;

    uint256 public Max_tokens_sold=100000000*1e18;

    uint256 public minimum_buy_usd=10*1e18;

    uint256 public total_tokens_sold=0;

    mapping (int256 => uint256) public Levels;

    mapping (address => bool) public whitelist;

    mapping ( address => userdata ) private  Users;

    mapping (address => mapping (int256 => uint256)) public cashback_levels_count;

    mapping (address => string) public username_dapp;

    struct userdata{
        address parent;
        uint256 total_cashback;
        uint256 count_referral;
        address [] children;
        string [] children_string;
    }

    modifier isVaildReferer( address _ref ){
        require(whitelist[_ref]==true);
        _;
    }

    modifier isValidUsername(){
        require(bytes(username_dapp[msg.sender]).length>0, "no existing username");
        _;
    }

    modifier isActive(  ){
        require( active == true );
        _;
    }

    modifier isInactive(  ){
        require( active == false );
        _;
    }

    event puchaseEvent( address indexed _buyer , address indexed _referer , uint256 _value);

    constructor() Wallet() PriceConsumerV3() {
        Levels[1]=15;
        Levels[2]=5;
        Levels[3]=4;
        Levels[4]=1;
        Levels[5]=3;
        Levels[6]=2;
        max_levels=6;
        active=true;
        whitelist[msg.sender]=true;    
    }

    function activate() onlyOwner isInactive public returns ( bool ) {
        active = true;
        return true;
    }

    function inactivate() onlyOwner isActive public returns ( bool ) {
        active = false;
        return true;
    }

    function getActive() public view returns(bool){
        return active;
    }

    function change_maxlevels(int256 new_maxlevel) onlyOwner public returns ( bool ) {
        if (new_maxlevel>max_levels){
            int256 level=max_levels+1;
            while (level<=new_maxlevel) {
                Levels[level]=0;
                level++;
            }
        }
        max_levels=new_maxlevel;
        return true;
    }

    function change_level(int256 level, uint256 value_level) onlyOwner public returns ( bool ) {
        require(level<=max_levels);
        Levels[level]=value_level;
        return true;
    }

    function change_Max_tokens_sold(uint256 new_maximum) onlyOwner public returns (bool){
        require(new_maximum>total_tokens_sold);
        Max_tokens_sold=new_maximum;
        return true;
    }

    function change_mimnimum_buy_usd(uint256 new_minimum) onlyOwner public returns (bool){
        minimum_buy_usd=new_minimum;
        return true;
    }

    function add_whitelist(address _ref) onlyOwner public returns (bool) {
        whitelist[_ref]=true;
        return true;
    }

    function getParent(address _ref) public view returns (address){
        return Users[_ref].parent;
    }

    function getCashback(address _ref) public view returns (uint256){
        return Users[_ref].total_cashback;
    }

    function getChildren(address _ref) public view returns (address [] memory){
        return Users[_ref].children;
    }

    function getChildrenString(address _ref) public view returns (string [] memory){
        return Users[_ref].children_string;
    }

    function getCountReferral(address _ref) public view returns (uint256){
        return Users[_ref].count_referral;
    }

    function getChainParent(address user) public view returns(address[] memory){
        int256 count=1;
        address[] memory listParents= new address[](uint256(max_levels));
        address Parent=Users[user].parent;
        while(count <= max_levels && Parent != address(0)){
            listParents[uint256(count-1)]=Parent;
            Parent=Users[Parent].parent;
            count++;
        }
        return listParents;
    }

    function purchase(address _referer, string memory username, uint256 tokens) isActive isVaildReferer( _referer ) payable public returns (bool)
    {
        require(_referer!=msg.sender,"Address must differs of your");
        require(bytes(username).length<=20 && bytes(username).length>0);
        int256 count=1;
        //Condition on the number of tokens
        uint256 tokenswei18=tokens*1e18;
        require(tokenswei18>=100*1e18,"Minimum 100 tokens to buy");
        require((tokenswei18+total_tokens_sold)<=Max_tokens_sold,"Sold out");
        //Condition on the quantity of bnb sent
        uint256 lastPrice=uint256(getLatestPriceWei18());
        uint256 value_usd=(msg.value*lastPrice)/1e18;
        require(value_usd>=minimum_buy_usd,"Minimum 10$ to buy");

        address Parent=_referer;
        uint256 countdown=100;

        _send(_owner, msg.sender, tokenswei18, "","", false);
        total_tokens_sold=total_tokens_sold+tokenswei18;
        
        while(count <= max_levels && Parent != address(0)){
            payable(Parent).transfer(msg.value*Levels[count]/100);
            Users[Parent].total_cashback = Users[Parent].total_cashback + (msg.value * Levels[count] / 100);
            cashback_levels_count[Parent][count]++;
            Parent=Users[Parent].parent;
            countdown=countdown-Levels[count];
            count=count+1;
        }

        if (whitelist[msg.sender]==false){
            username_dapp[msg.sender]=username;
        }
        Users[msg.sender].parent=_referer;
        Users[_referer].children.push(msg.sender);
        Users[_referer].children_string.push(username);
        Users[_referer].count_referral++;
        whitelist[msg.sender]=true;
        
        wallet.transfer(msg.value*countdown/100);
        
        emit puchaseEvent( msg.sender , Users[ msg.sender ].parent , msg.value);
        return true;
    }  
    
}
