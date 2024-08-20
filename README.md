# BinkTry3 - Poker Odds Calculator

BinkTry3 is a Swift-based poker odds calculator app that allows users to calculate the equity of various poker hands during a Texas Hold'em game. This project is built using Swift and SwiftUI, and it includes functionalities such as hand evaluation, deck management, and odds calculation through Monte Carlo simulations.

## Features

- **Card Deck Management**: Manage a deck of cards, including shuffling, dealing, and removing cards.
- **Player Management**: Add or remove players, and manage their hands.
- **Community Cards**: Manage the community cards on the poker table.
- **Equity Calculation**: Calculate the equity (winning percentage) of each player's hand using Monte Carlo simulations.
- **Custom Hand Evaluation**: Evaluate the best possible hand from a combination of player and community cards.

## Code Overview

### Enums

- **CardSuit**: Represents the four suits in a deck of cards (`diamonds`, `clubs`, `hearts`, `spades`).
- **CardRank**: Represents the rank of a card (`two` through `ace`).

### Structs

- **Card**: A struct representing a playing card, including its rank and suit.
- **Player**: A struct representing a player at the poker table, including an ID and a hand of cards.

### Classes

- **PokerTable**: The main class managing the poker game state, including players, community cards, deck, and results. It also handles card dealing, equity calculation, and hand evaluation.

### Views

- **PlayerCardView**: A custom SwiftUI view for displaying individual cards in a player's hand.
- **CustomCardView**: A custom SwiftUI view for displaying individual cards on the poker table.
- **ContentView**: The main view of the app, where users can interact with the poker table, add players, select cards, and calculate equity.

### Key Functions

- **resetDeck()**: Resets the deck of cards.
- **addPlayer()**: Adds a new player to the table.
- **addCard(to:player:card:)**: Adds a card to a player's hand.
- **addCommunityCard(card:)**: Adds a card to the community cards.
- **calculateOdds()**: Calculates the odds of winning for each player using Monte Carlo simulations.
- **evaluateBestHand(_:communityCards:)**: Evaluates the best possible hand from the player's hand and community cards.

## Usage

1. **Adding Players**: 
   - Click the **"Add Player"** button to add more players to the game. Each new player will be assigned a unique ID.
   
2. **Selecting Cards**: 
   - Tap on any of the card slots (either in the player's hand or in the community cards) to open the card picker.
   - In the card picker:
     - Select the **Rank** (2, 3, 4, …, K, A) and **Suit** (♦️, ♣️, ♥️, ♠️) of the card.
     - The selected card will appear in the chosen slot on the table.
     - You can change or remove the selected card before confirming your selection.

3. **Calculating Equity**: 
   - Once all players' hands and the community cards are set, press the **"Calculate"** button.
   - The app will simulate numerous poker hands to determine the win percentage and equity for each player.
   - The results will be displayed under each player's section, showing their chances of winning and their equity share.

4. **Resetting the Table**: 
   - To reset the game and start over, simply relaunch the app. This will reset the deck and clear all player hands and community cards.
