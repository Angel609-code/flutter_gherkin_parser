Feature: Testing regex‐driven step definitions

Scenario: Enter text with lookahead
  When I enter "searchTerm" into the search

Scenario: Items in category
  Given I have 5 items in category Books
  And   I have 1 item in category Toys

Scenario: Print with optional height and age
  Then I print Alice with height 170cm and age 30
  And  I print Bob and age 25

Scenario: Match multiple groups
  When I do foo at position 42 end with code A1B2 and flag 0
  And  I do bar at position 7 end with code FFFF and flag 1

Scenario: Process multiline text
  Then I see text: Hello world END section Main, number 10, flag 1, type urgent
  And  I see text: Another block of text including spaces END section Sec1, number 5, flag 0, type normal

Scenario: Process six captures
  Given I process Task1 and foo at 250ms for code ABC1 with user "john" in group Admin
  And   I process Report and bar at 100ms for code 1F2E with user "alice" in group Users
