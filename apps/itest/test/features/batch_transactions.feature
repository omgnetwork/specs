Feature: Transactions

  Scenario: 3 entities deposit ETH and exchange transactions
    When they deposit "10" ETH to the root chain
    Then they should have "10" ETH on the child chain after finality margin
    When they send each other batch transactions for "1" WEI on the child chain
    Then "Bob" should have "10000000000000000001" WEI on the child chain