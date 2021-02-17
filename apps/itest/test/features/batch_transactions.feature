Feature: Transactions

  Scenario: 2 entities exchange ETH
    When Alice deposits "10" ETH to the root chain
    Then Alice should have "10" ETH on the child chain after finality margin
    When Alice sends Bob "3" batch transactions for "1" ETH on the child chain
    Then "Bob" should have "3" ETH on the child chain
