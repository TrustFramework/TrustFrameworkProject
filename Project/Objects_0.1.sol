// SPDX-License-Identifier: RANDOM_TEXT
pragma solidity 0.6.12;

library Objects {
    struct Device {
        //address devaddress; //check
        uint256 reputation; //check
        uint256 failedTx;
        //bytes32 hUID; //check
        uint16 reviewCount; // number of reviews the service provider has //check
        //address[] valid_Reputers; // temporary array to hold reputers that can repute the device
        mapping(address => ValidReputers) valid; //mapping of reputers using their address
        mapping(uint256 => feedback) feedbacks;
        uint256 first_feedback;
        //address[] oracles; //temporary array for assigned oracles to assist it
        //mapping(address => Objects.OracleResponses) responseR; // response object for the oracle
        bool registered; // registered flag //check
        //metaData mD;// metadata object
    }

    struct feedback {
        uint256 feedback;
        uint256 time;
    }

    struct AuthList {
        //check
        address device;
        uint256 index;
        bool exists;
        bytes32 UID;
        int256 counter;
        address[] oracles;
        mapping(address => OracleResponses) oracResponse;
        uint256 requestTime;
    }

    struct ValidReputers {
        //address validreputer;
        uint16 txCount; // number of currents requests/transactions  TODO: Remove, can use txID.length
        bool valid; //valid reputer that is able to review
        //bytes32[] txIDs; // contains the transaction ID of the service the service requester requested
        mapping(bytes32 => transaction) txs; // mapping of the requested transactions by ID
    }

    struct Oracle {
        address oracle;
        uint256 index;
        uint256 successfulTxs;
        uint256 unsuccessfulTxs;
        bool head;
        bool registered;
    }

    struct OracleResponses {
        //address device;
        uint32 value;
        bool hUID;
        bool responded;
    }

    struct transaction {
        //check
        bytes32 txID;
        uint256 txTime_executed; // time that the transaction was executed ( at first its the time it was accepted) //check
        /////////////////////////time contraints
        uint256 timeStart;
        uint256 timeEnd;
        bool timeBased;
        ////////////////////////
        bool valid; // once the service provider accepts the request
        bool serviced; // true only once transaction serviced
        ////////////////////////post-feedback
        //uint256 fbTime; // time of feedback
        //bytes32 reviewID; // ID of transaction feedback
        //uint256 feedback;
        //bool reviewed; // registered feedback
    }
    /*
   struct metaData{
    uint256 responseTime;// time it takes for device to provide service
    uint256 availability;// on-demand updates or communication
    uint256 quality;// quality of service
    uint256 scalability;// ability to utilize resources for large-scale tasks
    uint256 efficiency;// power-resources consumed in comparison to service executed
    uint256 portability;// ability to adapt to different environments
  }*/
}
