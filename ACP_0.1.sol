// SPDX-License-Identifier: RANDOM_TEXT
pragma solidity 0.6.12;
import "./Objects.sol";
import "./Oracles.sol";


contract ACP{
    Oracles oracleObj;
    address oraclesAddress;
    address owner;
    //address[] deviceAdresses;// hold participating device address
    mapping (address =>Objects.Device) public device;// device struct
    //mapping (address => Objects.ValidReputers) validReputers;// validreputers structs  //probably do not need this, check
    //address[] reputerAdresses;// hold reputing addresses  //probably do not need this, check
    
    uint256 prevTxTime=now;// keep track of latest transaction
    //uint256 devcount=0;
  
   // add a registered flag so as not to allow duplicate users to execute actions
   // add modifiers
    modifier notDevice {
        require(!device[msg.sender].registered,"User should not be a registered device");
        _;
    }
    
    modifier isDevice {
        require(device[msg.sender].registered,"User should be registered as a device");
        _;
    }
    
     modifier isOwner {
        require(msg.sender == owner,"Only the contract owner is allowed to call the function");
        _;
    }
    /*modifier notReputer {
        require(!validReputers[msg.sender].valid,"User should not be a registered reputer");
        _;
    }
    
    modifier isReputer {
        require(validReputers[msg.sender].valid,"User should be a registered reputer");
        _;
    }*/
    
    modifier isOracle{
        require(oracleObj.isOracleRegistered(msg.sender), "User should be a registered oracle");
        _;
    }
    
    modifier isOracleContract{
        require(oraclesAddress == msg.sender, "User should be a registered oracle");
        _;
    }
    
    modifier notOracle{
        require(!oracleObj.isOracleRegistered(msg.sender), "User should not be a registered oracle");
        _;
    }
    
    function isDeviceRegistered(address _device) public view returns (bool) {
        return device[_device].registered;
    }
    
    function setOracContract(address _contract) public {
        oracleObj = Oracles(_contract);
        oraclesAddress= _contract;
    }
    
    modifier notRegistered {
        require(msg.sender != owner && !device[msg.sender].registered && !oracleObj.isOracleRegistered(msg.sender),"User should not be already registered");
        _;
    }
    
    
    constructor() public {
        owner = msg.sender;
    }
   
   
   
    function authDev(bytes32 _uID) public notDevice{
       oracleObj.authRequest(msg.sender, _uID);
    }
    
    event deviceRegistration(string s);
    function registerDev(address _dev, bytes32 /*_uID*/) public isOracleContract{
        Objects.Device memory dev;
        dev.reviewCount= 0;
        dev.first_feedback=0;
        dev.reputation= 5000;//scaled to maintain precision in fractional operations
        dev.registered=true;
        device[_dev]= dev;
        emit deviceRegistration ("A new device has been registered");
    }
     
   
   
    event registered(uint256 feedback, uint256 txtime,bytes32 ID);
    event newRep(uint256 rep,uint256 count);
    event submitReview (string s);
    function registerFeed(address _dev, uint256 _feedback, bytes32 _txID)public notRegistered {
        require(device[_dev].registered //check device exists
        && device[_dev].valid[msg.sender].txs[_txID].serviced //service was provided by device
        && device[_dev].valid[msg.sender].valid //check that it is a valid reputer for this device
        ,"invalid reputation transaction");// check that its a valid transaction for this device
        require(_feedback < 10000 ,"Invalid feedback value");
        //initiate review variables and compute reputation
        uint256 reviewTime= block.timestamp;
        bytes32 reviewID= keccak256(abi.encodePacked(msg.sender, reviewTime));
        emit registered(_feedback, reviewTime, reviewID);
        reputationComputation(_feedback,reviewTime, _dev);//Update the reputation for this device 
        device[_dev].reviewCount++;
        if(device[_dev].reviewCount>20){ // a queue of 20 feedbacks is kept to compute a truncated feedback
            device[_dev].feedbacks[device[_dev].reviewCount]= Objects.feedback(_feedback,reviewTime);
            delete device[_dev].feedbacks[device[_dev].first_feedback];
            device[_dev].first_feedback++;
        }
        else //if less than 20 then feedback is simply added
            device[_dev].feedbacks[device[_dev].reviewCount]= Objects.feedback(_feedback,reviewTime);
        device[_dev].valid[msg.sender].txCount--;
        //update data to remove mapping to this transaction with all its associations
        emit newRep(device[_dev].reputation,device[_dev].reviewCount);
        if(device[_dev].valid[msg.sender].txCount==0){// no transactions left for this device
            device[_dev].valid[msg.sender].valid=false;
        }
        device[_dev].valid[msg.sender].txs[_txID].valid=false;
        delete device[_dev].valid[msg.sender].txs[_txID];
        prevTxTime=reviewTime;//update time of the last transaction
        oracleObj.submitReview(msg.sender, reviewID); // Notify oracle cluster of a new review to be added
        emit submitReview ("reputation computed, please submit the review to the oracle cluster");
    }
    
    event serviceBC(string category, uint startTimePeriod,uint endTimePeriod, string Area);
    function serviceBroadcast(string memory _category, uint _startTimePeriod,uint _endTimePeriod, string memory Area) public {//Used in case device wants to notify of services provided
        emit serviceBC (_category, _startTimePeriod, _endTimePeriod, Area);
    }
     
     //done
     event service(bytes32 ID, uint256 txtime, uint txCount);
     function selectDev(address _dev, uint _startTimePeriod ,uint _endTimePeriod)public notRegistered{// avoid duplication
         require(device[_dev].registered, "Invalid Device!");// choose one of the available devices
         if(device[_dev].valid[msg.sender].valid)// only transaction added
            device[_dev].valid[msg.sender].txCount++;
         else{                                  // The requester and corresponding transaction added
             Objects.ValidReputers memory vrep;
             vrep.valid=true;
             vrep.txCount=1;
             device[_dev].valid[msg.sender] = vrep;
         }
         // Add the trasnaction with defined properties
         uint256 txTime= now;
         bytes32 ID= keccak256(abi.encodePacked(msg.sender,txTime));
         Objects.transaction memory transact;
         transact.txID= ID;
         transact.valid= true;
         transact.txTime_executed= txTime;
         device[_dev].valid[msg.sender].txs[ID] = transact;
         if(_startTimePeriod != 0 && _endTimePeriod !=0){// set time constraints based on requester preference
            require(_startTimePeriod > now + 1 minutes && _endTimePeriod > _startTimePeriod + 1 minutes,
            " The provided time constraints are not valid!" );// require feasible window
            device[_dev].valid[msg.sender].txs[ID].timeStart= _startTimePeriod;
            device[_dev].valid[msg.sender].txs[ID].timeEnd= _endTimePeriod;
            device[_dev].valid[msg.sender].txs[ID].timeBased=true;
         }
         emit service(ID,txTime, device[_dev].valid[msg.sender].txCount);
     }
     
    
     event encryptedlink(bytes32 encryptedIPFSHash);// the ecnryptedhash using the requesters publickey to the service data, encrypted by public key of requester
     function executeService(address _user, bytes32 _txID, bytes32 _encIPFSHash)public isDevice returns(string memory){
         require(!device[msg.sender].valid[_user].txs[_txID].serviced && 
            device[msg.sender].valid[_user].txs[_txID].valid);// check has not already been serviced and tx still valid
         if(device[msg.sender].valid[_user].txs[_txID].timeBased)// check if there are time constraints
           if ( device[msg.sender].valid[_user].txs[_txID].timeEnd < now || 
            now < device[msg.sender].valid[_user].txs[_txID].timeStart){//check if within time contraints
               delete device[msg.sender].valid[_user].txs[_txID];
               device[msg.sender].failedTx++;//penalize
               return(" Not within time contraints, transaction will be revoked");
           }
                    
         device[msg.sender].valid[_user].txs[_txID].serviced=true;
         emit encryptedlink(_encIPFSHash);// share encryptedlink
         return "The service has been executed successfully";
     }
     
     
      function getReputation(address _device) public view returns(uint) {
         return device[_device].reputation;
     }
     
    function computeReputation(address _dev) public view returns (uint){
        //initiate request to compute a reputation for a specific device, this is then conveyed to oracle smart contract to handle
        uint avg = 0;
        for(uint i=device[_dev].first_feedback;i<=device[_dev].reviewCount;i++){
            avg+= device[_dev].feedbacks[i].feedback;
        }
        avg /= device[_dev].reviewCount;
        return avg;
    }
    
       event test(uint256 test);
     //uint z= 5000;
     function reputationComputation( uint _feedback, uint _fbTime, address _dev) internal {
        // time_weight: [0, 15780000]
        // feedback: [0, 10000]
        // weighted_feedback: [0,157800000000] \\[0, 2**48 - 1]
        // reputation: [0, 10000]
        //uint feedback = uint16(_feedback); // 10000
        uint time_weight = _fbTime - prevTxTime; // 203656
        uint range=  15780000;// [0, 2**32 - 1] //4294967295
        uint range_Ulimit= 12624000;
        uint range_Llimit= 789000;
        if(time_weight> range_Ulimit)
            time_weight= range_Ulimit;
        if(time_weight> range_Ulimit)
            time_weight= range_Llimit;
        device[_dev].reputation = (((range - time_weight) * device[_dev].reputation) + (time_weight * _feedback)) / range;
        emit test(device[_dev].reputation);
     }
    
}

contract ComputationMechanisms is ACP{
    constructor() public {
        address owner = msg.sender;
    }
  
    function reputationAvgMean(address _dev, uint256 _feedback ) public{
          device[_dev].reputation= ((device[_dev].reputation*(device[_dev].reviewCount-1))+_feedback)/device[_dev].reviewCount;
    }
}
