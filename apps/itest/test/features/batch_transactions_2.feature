Feature: Transactions

  Scenario: A batch transaction has two successful and one failed transaction
    When they deposit "10" ETH to the root chain
    Then they should have "10" ETH on the child chain after finality margin
    When Alice and Eve start a batch transactions for "1" WEI to Bob on the child chain
    When Bob adds a transactions for "1" WEI that uses a non existing UTXO on the child chain
    Then "Bob" should have "10000000000000000002" WEI on the child chain
    Then the batch transaction response should have a error on the third index

