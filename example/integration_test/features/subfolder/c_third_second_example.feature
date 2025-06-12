Feature: Testing fail on background

Background:
    # Failing in background
    Given I have 5 items in category Books

Scenario: Second example of escenario
    And I fill the "search" field with "Tofu"
    And I check non-grouping
    Then I print "hello" or maybe this non-grouping with this as param or this two