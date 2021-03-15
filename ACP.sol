// SPDX-License-Identifier: RANDOM_TEXT
pragma solidity 0.6.12;
import "./Objects.sol";
import "./Oracles.sol";
// Variables everywhere, eliminate the constraints
// check edge cases

contract ACP{
    Oracles oracleObj;
    ComputationMechanisms compMechObj;
    address oracleSC; address compSC; // contracts that will be linked to the main contract
    address owner;
    mapping (address =>Objects.Device) public device;// device struct

    
    uint256 prevTxTime=now;// keep track of latest transaction
  
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
        require(oracleSC == msg.sender, "User should be a registered oracle");
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
        oracleSC= _contract;
    }
    
      function setCompContract(address _Compcontract) public {
        compMechObj = ComputationMechanisms(_Compcontract);
    }
    
    modifier notRegistered {
        require(msg.sender != owner && !device[msg.sender].registered && !oracleObj.isOracleRegistered(msg.sender),"User should not be already registered");
        _;
    }
    
    
    constructor() internal {
        owner = msg.sender;
    }
   

    bytes32 services;
    function authDev(bytes32 _uID, bytes32 _services) public notDevice{
       services= _services;
       oracleObj.authRequest(msg.sender, _uID);
    }
    
    event deviceRegistration(string S, bytes32 Services);
    function registerDev(address _dev, bytes32 /*_uID*/) public isOracleContract{
        Objects.Device memory dev;
        dev.reviewCount= 0;
        dev.first_feedback=0;
        dev.reputation= 5000;//scaled to maintain precision in fractional operations
        dev.registered=true;
        device[_dev]= dev;
        emit deviceRegistration ("A new device has been registered", services);

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
        //compMechObj.reputationAvgMean(_dev, _feedback );
        
        device[_dev].reviewCount++;
        if(device[_dev].reviewCount>20){ // a queue of 20 feedbacks is kept to compute a truncated feedback
            device[_dev].feedbacks[device[_dev].reviewCount]= Objects.feedback(_feedback,reviewTime);
            delete device[_dev].feedbacks[device[_dev].first_feedback];
            device[_dev].first_feedback++;
        }
        else //if less than 20 then feedback is simply added
            device[_dev].feedbacks[device[_dev].reviewCount]= Objects.feedback(_feedback,reviewTime);
            
        device[_dev].valid[msg.sender].txCount--;
        device[_dev].valid[msg.sender].revCount++;
        //update data to remove mapping to this transaction with all its associations
        emit newRep(device[_dev].reputation, device[_dev].reviewCount);
        if(device[_dev].valid[msg.sender].txCount==0){// no transactions left for this device
            device[_dev].valid[msg.sender].valid=false;
        }
        device[_dev].valid[msg.sender].txs[_txID].valid=false;
        delete device[_dev].valid[msg.sender].txs[_txID];
        prevTxTime=reviewTime;//update time of the last transaction
        oracleObj.submitReview(msg.sender, reviewID); // Notify oracle cluster of a new review to be added
        //emit submitReview ("reputation computed, please submit the review to the oracle cluster");
    }
    
     
     //done
     event serviceReq (address _dev, uint _startTimePeriod,uint _endTimePeriod, uint8 _priority);
     function serviceRequest(address _dev, uint _startTimePeriod,uint _endTimePeriod, uint8 _priority) external notDevice{
         address _requester=msg.sender;
         device[_dev].valid[_requester].pendingReq=_dev;
         emit serviceReq (_dev, _startTimePeriod,_endTimePeriod, _priority);
     }
     function cancelServiceRequest(address _dev) external {
         require(device[_dev].valid[msg.sender].pendingReq == _dev);
         device[_dev].valid[msg.sender].pendingReq = address(0);
     }
     
     event serviceDetails(bytes32 ID, uint256 txtime, uint txCount);

     function selectDev(address _requester, uint _startTimePeriod ,uint _endTimePeriod)public isDevice{// avoid duplication
         require(device[msg.sender].valid[_requester].pendingReq == msg.sender, "Invalid Device!");// choose one of the available devices
        address _dev=msg.sender;
        device[_dev].valid[_requester].pendingReq = address(0);
         //device[_dev].valid[msg.sender].validreputer = msg.sender;
         if(device[_dev].valid[_requester].valid)// only transaction added
            device[_dev].valid[_requester].txCount++;
         else{                                  // The requester and corresponding transaction added
             Objects.ValidReputers memory vrep;
             vrep.valid=true;
             vrep.txCount=1;
             device[_dev].valid[_requester] = vrep;
         }
         // Add the trasnaction with defined properties
         uint256 txTime= now;
         bytes32 ID= keccak256(abi.encodePacked(_requester,txTime));
         Objects.transaction memory transact;
         transact.txID= ID;
         transact.valid= true;
         transact.txTime_executed= txTime;
         device[_dev].valid[_requester].txs[ID] = transact;
         if(_startTimePeriod != 0 && _endTimePeriod !=0){// set time constraints based on requester preference
            require(_startTimePeriod > now + 1 minutes && _endTimePeriod > _startTimePeriod + 1 minutes,
            " The provided time constraints are not valid!" );// require feasible window
            device[_dev].valid[_requester].txs[ID].timeStart= _startTimePeriod;
            device[_dev].valid[_requester].txs[ID].timeEnd= _endTimePeriod;
            device[_dev].valid[_requester].txs[ID].timeBased=true;
         }
         emit serviceDetails(ID,txTime, device[_dev].valid[msg.sender].txCount);
     }
     
    function reputationComputation( uint _feedback, uint _fbTime, address _dev) internal {
        // time_weight: [0, 15780000]
        // feedback: [0, 10000]
        // weighted_feedback: [0,157800000000] \\[0, 2**48 - 1]
        // reputation: [0, 10000]
        //uint feedback = uint16(_feedback); // 10000
        // The values are mapped to larger range to acommodate for losses that occur due to division, and division is the last operation to be done to avoid losses
        uint time_weight = _fbTime - prevTxTime; // 203656
        uint range=  15780000;// This is approximately 6 months, so would provide variance for transactions with up 6 months difference // adjustable 
        uint range_Ulimit= 12624000; // adjustable value
        uint range_Llimit= 789000; // Adjustable value
        if(time_weight> range_Ulimit)
            time_weight= range_Ulimit;
        if(time_weight < range_Llimit)
            time_weight= range_Llimit;
        device[_dev].reputation = (((range - time_weight) * device[_dev].reputation) + (time_weight * _feedback)) / range;
     }
     
    
     event encryptedlink(bytes32 encryptedIPFSHash);// the ecnryptedhash using the requesters publickey to the service data, encrypted by public key of requester
     function executeService(address _user, bytes32 _txID, bytes32 _encIPFSHash)external isDevice returns(string memory){
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
}

 contract ComputationMechanisms is ACP{ ///// contract with the computation mechanisms
    constructor() public isOwner {
         owner = msg.sender;
    }
    
    function reputationAvgMean(address _dev, uint256 _feedback ) external{
          device[_dev].reputation= ((device[_dev].reputation*(device[_dev].reviewCount-1)) +_feedback)/device[_dev].reviewCount;
    }
    
      function computeReputation(address _dev) public view returns (uint){
        //initiate request to compute a reputation for a specific device, this can be instead submitted for oracles to compute
        //This follows case 3, where this function is called once there are X new feedbacks since last computation
        //
        uint avg = 0;
        for(uint i=device[_dev].first_feedback;i<=device[_dev].reviewCount;i++){
            avg+= device[_dev].feedbacks[i].feedback;
        }
        avg /= device[_dev].reviewCount;
        return avg;
    }
    
    function reputationweighted( uint _feedback, uint _revCount, uint _priority, uint _fbTime, address _dev) public { // has to be synchronus or manually computed (User or oracles)
        require(_priority>=1 || _priority <=5);
        uint time_weight = _fbTime - prevTxTime; 
        uint range=  15780000;// [0, 2**32 - 1] //4294967295
        if(_revCount>1000)
            _revCount=1000;
        uint weight=0;
        uint range_Ulimit= 10000000;
        uint range_Llimit= 789000;
        if(time_weight> range_Ulimit)
            time_weight= range_Ulimit;
        else if(time_weight < range_Llimit)
            time_weight= range_Llimit;
        _priority= _priority*200000;
        _revCount= _revCount* 1000;
        
        weight= _priority+_revCount+time_weight;
            
        // each priority level is : 200000, with 1 being low (200000) and 5 being high(1000000)
        //revcountmax is 1000: and is the upper limit for the constant weight factor
        
        device[_dev].reputation = (((range - weight) * device[_dev].reputation) + (weight * _feedback)) / range;
     }
    
      function getReputation(address _device) external view returns(uint) {
         return device[_device].reputation;
     }
}
