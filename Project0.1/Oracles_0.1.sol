// SPDX-License-Identifier: RANDOM_TEXT
pragma solidity 0.6.12;
import "./Objects.sol";
import "./ACP.sol";

/*struct Oracle{
    address oracle;
    bool head;
    bytes32 clusterID;
    bool registered;
}*/

contract Oracles {
    /* modifier notRegistered {
       require(!validReputers[msg.sender].registered && !ACP.device[msg.sender].registered && !validOracle[msg.sender].registered," should not be registered");
        _;
    }*/

    modifier isOracle {
        require(
            validOracle[msg.sender].registered,
            "User should be registered Oracle!"
        );
        _;
    }

    modifier notOracle {
        require(
            !validOracle[msg.sender].registered,
            "User should be registered Oracle!"
        );
        _;
    }

    modifier isHead {
        require(msg.sender == head, "User should be registered head!");
        _;
    }

    modifier notHead {
        require(msg.sender != head, "User should not be the cluster head!");
        _;
    }

    modifier notDevice {
        require(
            !acp.isDeviceRegistered(msg.sender),
            "User should not be a registered device"
        );
        _;
    }

    modifier isACP {
        require(
            msg.sender == acpAdress,
            "Users are not eligible to call the function!"
        );
        _;
    }
    
    function isOracleRegistered(address _oracle) public view returns (bool) {
        return validOracle[_oracle].registered;
    }

    ACP acp;
    address acpAdress;
    address head;
    address potentialHead;
    address owner;
    bytes32 dnsLink;
    uint256 nonce = block.timestamp;
    //uint256 oraclecount = 0;
    address[] oracleAddresses;
    address[] authList;
    mapping(address => Objects.Oracle) validOracle;
    mapping(address => Objects.AuthList) authDev;
    mapping(bytes32 => reviews) reviewPost;
    struct reviews {
        bytes32 reviewId;
        bytes32 entry;
        address disputer;
        address[] validitors;
        uint8 attest;
        uint8 deny;
    }

    constructor(address _acp) public {
        owner = msg.sender;
        acpAdress = _acp;
        acp = ACP(acpAdress);
    }

    ////done
    event HUID(address device, bytes32 unique_ID); // this is called in the ACP contract

    function authRequest(address _dev, bytes32 _uID) public isACP {
        // request oracles to authenticate this device
        emit HUID(_dev, _uID);
        //push and initialize device in the authentication list
        authList.push(_dev);
        Objects.AuthList memory auth;
        auth.device = _dev;
        auth.exists = true;
        auth.UID = _uID;
        auth.counter = 0;
        auth.index = authList.length - 1;
        auth.requestTime = block.timestamp;
        authDev[_dev] = auth;
    }

    //event counter(int256 counter);
    //emit counter(authDev[_authDev].counter); /*_authDev,*/ 

    ////done //TODO: make sure oracles can not vote more than once
    function aggregateOracleVote(address _authDev, bytes32 _uID, bool _hUID) public isOracle {
        require(authDev[_authDev].exists && authDev[_authDev].UID == _uID,
            "A device with the specified unique identifier is not valid!"
        );// validate that the vote is for the specific device
        require(!authDev[_authDev].oracResponse[msg.sender].responded,
            "Oracle can only vote once!"
        ); // Avoid double voting
        //increment or decrement counter based on oracle vote then record the response
        _hUID ? authDev[_authDev].counter++ : authDev[_authDev].counter--;
        authDev[_authDev].oracles.push(msg.sender);
        authDev[_authDev].oracResponse[msg.sender] = Objects.OracleResponses(0,_hUID, true);
        if (// if all oracles voted OR half of them did after a certain time period, condition satisfied
            ((block.timestamp - authDev[_authDev].requestTime) > 10 minutes  &&
            authDev[_authDev].oracles.length > (oracleAddresses.length / 2)) ||
            authDev[_authDev].oracles.length == oracleAddresses.length
        ) {
            authDevice(_authDev, _uID);// call authentication function to register or reject device
        }
    }

    event authStatus(string _status);

    ////done
    function authDevice(address _authDev, bytes32 _uID) internal {
        bool result;
        if (authDev[_authDev].counter > 0) result = true;// set authentication result
        // update oracles credibility
        for (uint256 j = 0; j < (authDev[_authDev].oracles.length); j++) {
            result ==authDev[_authDev].oracResponse[authDev[_authDev].oracles[j]].hUID
                ? validOracle[authDev[_authDev].oracles[j]].successfulTxs++
                : validOracle[authDev[_authDev].oracles[j]].unsuccessfulTxs++;
            if (
                (validOracle[authDev[_authDev].oracles[j]].successfulTxs -
                    validOracle[authDev[_authDev].oracles[j]].unsuccessfulTxs) >
                (validOracle[potentialHead].successfulTxs -
                    validOracle[potentialHead].unsuccessfulTxs)
            ) potentialHead = validOracle[authDev[_authDev].oracles[j]].oracle;
            delete authDev[_authDev].oracResponse[authDev[_authDev].oracles[j]];// delete mappings
        }
        delete authDev[_authDev].oracles;// delete oracles list associated with device
        removeDevice(authDev[_authDev].index);
        delete authDev[_authDev];
        //in both cases the device removed from devices to be authenticated list
        if (result) {// if true, registration function called from ACP
            emit authStatus("The device has been authenticated");
            acp.registerDev(_authDev, _uID);
        } else // if false, device is not registered
            emit authStatus("The device has been rejected");
    }

    ////done
    function registerOracle() public notDevice notOracle {
        Objects.Oracle memory orac;
        orac.oracle = msg.sender;
        if (oracleAddresses.length == 0) {
            orac.head = true;
            head = orac.oracle;
            emit getdnsLink();
        }
        if (oracleAddresses.length == 1) {
            potentialHead = orac.oracle;
        }
        oracleAddresses.push(msg.sender);
        orac.registered = true;
        orac.index = oracleAddresses.length - 1;
        validOracle[msg.sender] = orac;
    }

    event getdnsLink();

    function electOracle() internal isOracle {
        // this will only happen if there is misbehaviour in the system
        removeOracle(validOracle[head].index);
        validOracle[potentialHead].head = true;
        head = potentialHead;
        emit getdnsLink();
    }

    function updateHeadLink(bytes32 _dnsLink) public isHead {
        dnsLink = _dnsLink;
    }

    event reviewsubmission(address requester, bytes32 ID, address head);

    function submitReview(address _requester, bytes32 _ID) public isACP {
        //called by ACP to notify oracles that user submits review
        emit reviewsubmission(_requester, _ID, head);
        reviews memory rev;
        rev.reviewId = _ID;
        reviewPost[_ID] = rev;
    }

    event reviewsubmissionResult(string s);

    function submitReviewResult(bytes32 _ID, bytes32 _entry) public isHead {
        // head replies with the status of upload
        require(reviewPost[_ID].reviewId == _ID);
        if (_entry == "")
            emit reviewsubmissionResult("User failed to submit a review.");
        else
            emit reviewsubmissionResult(
                "User has submitted review, and was added at specified entry."
            );
        reviewPost[_ID].entry = _entry;
        //TODO: Add incentive mechanism
    }

    event validateDispute(bytes32 ID, bytes32 entry);
    event validatorSelection(address [] validators);

    function challengeUpload(bytes32 _ID, bytes32 _entry)public isOracle notHead{
        require(reviewPost[_ID].entry == _entry);
        uint256 x = uint256(
            keccak256(abi.encodePacked(block.difficulty, block.timestamp, nonce))
            ) % oracleAddresses.length;
        nonce++;
        reviewPost[_ID].disputer = msg.sender;
        uint8 k = 0;
        while (k < (oracleAddresses.length / 2) - 1 && k < 10) {
        // randomely select an index and then select either odd or even half of oracles
            if (
                oracleAddresses[x] != head &&
                oracleAddresses[x] != reviewPost[_ID].disputer
            ) {
                reviewPost[_ID].validitors.push(oracleAddresses[x]);
                k++;
            }
            if (x >= oracleAddresses.length - 2) x = 0;
            else x += 2;
        }
        emit validatorSelection(reviewPost[_ID].validitors);
        emit validateDispute(_ID, _entry);
    }

    uint256 disputeTimer;

    function disputeVote(bytes32 _ID, bool _vote, uint8 _count) public isOracle notHead {
        require(msg.sender == reviewPost[_ID].validitors[_count],
            " Not eligible to attest!");
        if (reviewPost[_ID].attest + reviewPost[_ID].deny == 0)// timeout starts counting after first vote
            disputeTimer = block.timestamp;
        _vote ? reviewPost[_ID].attest++ : reviewPost[_ID].deny++;
        validOracle[msg.sender].successfulTxs++;// oracle incentive
        if (
            (reviewPost[_ID].attest + reviewPost[_ID].deny) ==
            reviewPost[_ID].validitors.length ||
            block.timestamp > disputeTimer + 10 minutes
        ) {
            if (reviewPost[_ID].attest >= reviewPost[_ID].validitors.length / 2
            ) {
                validOracle[reviewPost[_ID].disputer].successfulTxs += 2; //disputer incentive
                if(
                (validOracle[reviewPost[_ID].disputer].successfulTxs-
                 validOracle[reviewPost[_ID].disputer].unsuccessfulTxs) > 
                (validOracle[potentialHead].successfulTxs-
                 validOracle[potentialHead].unsuccessfulTxs)
                )// if sum is greater then it is potentialhead, otherwise potential head not adjusted
                    potentialHead=reviewPost[_ID].disputer;
                delete reviewPost[_ID].validitors;
                delete reviewPost[_ID];
                electOracle(); // new oracle head is selected
            } else {
                validOracle[reviewPost[_ID].disputer].unsuccessfulTxs += 2; //disputer penalty
                delete reviewPost[_ID].validitors;
                delete reviewPost[_ID];
            }
        }
    }

    event oracleCompute(bytes32 ipfshash, address dev);

    function removeOracle(uint256 _oracleIndex) internal {
        require(validOracle[oracleAddresses[_oracleIndex]].registered);
        delete validOracle[oracleAddresses[_oracleIndex]];
        oracleAddresses[_oracleIndex] = oracleAddresses[oracleAddresses.length -
            1];
        validOracle[oracleAddresses[_oracleIndex]].index = _oracleIndex;
        oracleAddresses.pop(); // recovers gas
    }

    function removeDevice(uint256 _devIndex) internal {
        //contains mapping so need to delete that too
        require(authDev[authList[_devIndex]].exists);
        for (
            uint256 z = 0;
            z < authDev[authList[_devIndex]].oracles.length;
            z++
        ) {
            delete authDev[authList[_devIndex]]
                .oracResponse[oracleAddresses[z]];
        }
        delete authDev[authList[_devIndex]];
        authList[_devIndex] = authList[authList.length - 1];
        authDev[authList[_devIndex]].index = _devIndex;
        authList.pop(); // recovers gas
    }
}

/*for(uint i=0; i < (oraclecount-1); i++){// loop and find the oracle with most successful contributions to the system and select as head
            if((validOracle[oracleAddresses[i+1]].successfulTxs - validOracle[oracleAddresses[i+1]].successfulTxs) 
            > (validOracle[oracleAddresses[i]].successfulTxs - validOracle[oracleAddresses[i]].successfulTxs)){
                newHead = validOracle[oracleAddresses[i]].oracle;
            }
        }*/
