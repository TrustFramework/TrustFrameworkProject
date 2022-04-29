// SPDX-License-Identifier: RANDOM_TEXT
pragma solidity 0.6.12;

library Objects {
    struct Device {
        uint256 reputation; 
        uint256 failedTx;
        uint16 reviewCount; // number of reviews the service provider has 
        mapping(address => ValidReputers) valid; //mapping of reputers using their address
        mapping(uint256 => feedback) feedbacks; //mapping ONLY to the recent feedbacks (QUEUE structure)
        uint256 first_feedback;
        bool registered; // registered flag 

    }

    struct feedback { // feedback struct to hold the value and time
        uint256 feedback;
        uint256 time;
    }

    struct AuthList { // struct to hold the devices being authenticated
        address device;
        uint256 index;
        bool exists;
        bytes32 UID;
        int256 counter;
        address[] oracles;
        mapping(address => OracleResponses) oracResponse;
        uint256 requestTime;
    }

    struct ValidReputers { // Valid requesters with their associated transactions
        address requester;
        address pendingReq;
        uint16 txCount; // number of currents requests/transactions 
        bool valid; //valid reputer that is able to review
        uint revCount;
        mapping(bytes32 => transaction) txs; // mapping of the requested transactions by ID
    }

    struct Oracle { // oracles details, with the transactionhistory to determine credibility
        address oracle;
        uint256 index;
        uint256 successfulTxs;
        uint256 unsuccessfulTxs;
        bool head;
        bool registered;
    }

    struct OracleResponses { // details of oracle responses
        //address device;
        uint32 value;
        bool hUID;
        bool responded;
    }

    struct transaction {// details of transactions to ensure correct linkability between unique transaction and the associated requester and provider
        bytes32 txID;
        uint256 txTime_executed; // time that the transaction was executed ( at first its the time it was accepted) //check
        /////////////////////////time contraints
        uint256 timeStart;
        uint256 timeEnd;
        bool timeBased;
        ////////////////////////
        bool valid; // once the service provider accepts the request
        bool serviced; // true only once transaction serviced
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
