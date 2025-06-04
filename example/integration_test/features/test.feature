//integration_test/features/test.feature
Feature: Testing the fill text form field

Background:
    Given I fill the "search" field with ""
    And I should see "Este programa de comida es para ti"
    And I print table
        |N|Nombre|estado|
        |1|John  |0     |
        |2|Jean  |1     |
    And I click in input with key "deletePost"

Scenario: Filling input
    And I fill the "search" field with "Tofu"
    And I fill the "search" field with "Club"

Scenario: Checking a second scenario
    And I fill the "search" field with ""
    And I fill the "search" field with "Tofu"