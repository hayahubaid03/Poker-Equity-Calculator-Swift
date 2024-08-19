//
//  ContentView.swift
//  BinkTry3
//
//  Created by Hayah Ubaid on 2024-08-08.
//


import Foundation
import SwiftUI

enum CardSuit: String, CaseIterable, Codable {
    case diamonds = "♦️"
    case clubs = "♣️"
    case hearts = "♥️"
    case spades = "♠️"
}

enum CardRank: String, CaseIterable, Codable {
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "T"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    case ace = "A"
}

struct Card: Hashable, Codable {
    var rank: CardRank
    var suit: CardSuit
    
    var description: String {
        return "\(rank.rawValue)\(suit.rawValue)"
    }
    
    var numericValue: Int {
        switch rank {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 14
        }
    }
}

struct Player: Hashable, Codable {
    var id: Int
    var hand: [Card] = []
}

enum PokerError: Error {
    case cardNotInDeck
    case invalidPlayer
    case invalidCard
    case deckExhausted
}

class PokerTable: ObservableObject {
    @Published var players: [Player] = []
    @Published var communityCards: [Card] = []
    @Published var deck: [Card] = []
    @Published var results: [String] = []

    init() {
        resetDeck()
        addInitialPlayers()
    }

    func resetDeck() {
        deck.removeAll()
        for rank in CardRank.allCases {
            for suit in CardSuit.allCases {
                deck.append(Card(rank: rank, suit: suit))
            }
        }
    }
    
    func addInitialPlayers() {
        // Add two players by default: Player 1 and Villain
        players.append(Player(id: 1))
        players.append(Player(id: 2))
    }

    func addPlayer() {
        let newPlayer = Player(id: players.count + 1)
        players.append(newPlayer)
    }

    func addCard(to player: Int, card: Card) throws {
            guard let index = players.firstIndex(where: { $0.id == player }) else { throw PokerError.invalidPlayer }
            guard deck.contains(card) else { throw PokerError.cardNotInDeck }
            
            // Safeguard to prevent array out-of-bounds errors
            if !players[index].hand.contains(card) && players[index].hand.count < 2 {
                players[index].hand.append(card)
                if let deckIndex = deck.firstIndex(of: card) {
                    deck.remove(at: deckIndex)
                }
            }
        }

    func addCommunityCard(card: Card) throws {
            guard deck.contains(card) else { throw PokerError.cardNotInDeck }
            
            // Safeguard to prevent array out-of-bounds errors
            if !communityCards.contains(card) && communityCards.count < 5 {
                communityCards.append(card)
                if let deckIndex = deck.firstIndex(of: card) {
                    deck.remove(at: deckIndex)
                }
            }
        }
    
    

    func calculateOdds() {
        guard communityCards.count >= 3 else { return }

        let numSimulations = 15000
        let totalPlayers = players.count
        var winCounts = Array(repeating: 0.0, count: totalPlayers)
        var tieCount = 0.0 // Track the total number of ties

        let concurrentQueue = DispatchQueue(label: "com.odds.simulation", attributes: .concurrent)
        let group = DispatchGroup()

        let simulationsPerBatch = numSimulations / ProcessInfo.processInfo.activeProcessorCount
        for _ in 0..<ProcessInfo.processInfo.activeProcessorCount {
            group.enter()
            concurrentQueue.async {
                for _ in 0..<simulationsPerBatch {
                    var remainingDeck = self.deck.shuffled() // Shuffle the deck for randomness
                    let additionalCommunityCards = 5 - self.communityCards.count

                    var simulatedCommunityCards = self.communityCards
                    for _ in 0..<additionalCommunityCards {
                        if let card = remainingDeck.randomElement(), let index = remainingDeck.firstIndex(of: card) {
                            simulatedCommunityCards.append(card)
                            remainingDeck.remove(at: index)
                        }
                    }

                    var bestHandRank = -1
                    var bestPlayerIndices: [Int] = []

                    for (index, player) in self.players.enumerated() {
                        let handRank = self.evaluateBestHand(player.hand, communityCards: simulatedCommunityCards)

                        if handRank > bestHandRank {
                            bestHandRank = handRank
                            bestPlayerIndices = [index]
                        } else if handRank == bestHandRank {
                            bestPlayerIndices.append(index)
                        }
                    }

                    if bestPlayerIndices.count == 1 {
                        winCounts[bestPlayerIndices[0]] += 1
                    } else {
                        let winPortion = 1.0 / Double(bestPlayerIndices.count)
                        for index in bestPlayerIndices {
                            winCounts[index] += winPortion
                        }
                        tieCount += 1
                    }
                }
                group.leave()
            }
        }

        group.wait()

        let tiePercentage = (tieCount / Double(numSimulations)) * 100

        results = players.enumerated().map { index, _ in
            let winPercentage = (winCounts[index] / Double(numSimulations)) * 100
            let equity = (tiePercentage / Double(totalPlayers)) + winPercentage
            return "Player \(index + 1): Win \(String(format: "%.2f", winPercentage))%, Equity \(String(format: "%.2f", equity))%"
        }

        results.append("Tie: \(String(format: "%.2f", tiePercentage))%")
    }
    // Hand evaluation logic

    func evaluateBestHand(_ cards: [Card], communityCards: [Card]) -> Int {
        var bestRank = 0
        let allPossibleHands = generateAllCombinations(cards + communityCards, handSize: 5)
        
        for hand in allPossibleHands {
            let rank = evaluateHand(hand)
            bestRank = max(bestRank, rank)
        }
        
        return bestRank
    }

    func generateAllCombinations(_ cards: [Card], handSize: Int) -> [[Card]] {
        guard handSize <= cards.count else { return [] }
        var result: [[Card]] = []
        var indices = Array(0..<handSize)
        
        while true {
            result.append(indices.map { cards[$0] })
            var i = handSize - 1
            while i >= 0 && indices[i] == i + cards.count - handSize {
                i -= 1
            }
            if i < 0 { break }
            indices[i] += 1
            for j in (i+1)..<handSize {
                indices[j] = indices[j-1] + 1
            }
        }
        return result
    }

    func combinations(_ elements: [Card], _ k: Int) -> [[Card]] {
        if k == 0 { return [[]] }
        guard let first = elements.first else { return [] }
        let subcombos = combinations(Array(elements.suffix(from: 1)), k - 1).map { [first] + $0 }
        return subcombos + combinations(Array(elements.suffix(from: 1)), k)
    }

    func evaluateHand(_ cards: [Card]) -> Int {
        let sortedCards = cards.sorted { $0.numericValue < $1.numericValue }
        let numValues = sortedCards.map { $0.numericValue }
        let suits = sortedCards.map { $0.suit }

        var handRank = 0

        // Check for Straight Flush
        if isStraight(numValues) && isFlush(suits) {
            handRank = 8000 + numValues.max()!
            return handRank // Return immediately as it's the highest possible rank
        }

        // Check for Four of a Kind
        if let fourOfAKindValue = findNOfAKind(numValues, n: 4) {
            let kicker = numValues.filter { $0 != fourOfAKindValue }.max()!
            handRank = 7000 + fourOfAKindValue * 16 + kicker
            return handRank
        }

        // Check for Full House
        if let threeOfAKindValue = findNOfAKind(numValues, n: 3),
           let pairValue = findNOfAKind(numValues, n: 2, excluding: threeOfAKindValue) {
            handRank = 6000 + threeOfAKindValue * 16 + pairValue
            return handRank
        }

        // Check for Flush
        if isFlush(suits) {
            handRank = 5000 + numValues.max()!
            return handRank
        }

        // Check for Straight
        if isStraight(numValues) {
            handRank = 4000 + numValues.max()!
            return handRank
        }

        // Check for Three of a Kind
        if let threeOfAKindValue = findNOfAKind(numValues, n: 3) {
            let kickers = numValues.filter { $0 != threeOfAKindValue }.sorted(by: >)
            handRank = 3000 + threeOfAKindValue * 16 + kickers[0] * 4 + kickers[1]
            return handRank
        }

        // Check for Two Pair
        if let firstPairValue = findNOfAKind(numValues, n: 2),
           let secondPairValue = findNOfAKind(numValues, n: 2, excluding: firstPairValue) {
            let kicker = numValues.filter { $0 != firstPairValue && $0 != secondPairValue }.max()!
            handRank = 2000 + max(firstPairValue, secondPairValue) * 16 + min(firstPairValue, secondPairValue) * 4 + kicker
            return handRank
        }

        // Check for One Pair
        if let pairValue = findNOfAKind(numValues, n: 2) {
            let kickers = numValues.filter { $0 != pairValue }.sorted(by: >)
            handRank = 1000 + pairValue * 16 + kickers[0] * 4 + kickers[1]
            return handRank
        }

        // High Card
        let kickers = numValues.sorted(by: >)
        handRank = kickers[0] * 16 + kickers[1] * 4 + kickers[2]
        
        return handRank
    }

    func isFlush(_ suits: [CardSuit]) -> Bool {
        return Set(suits).count == 1
    }

    func isStraight(_ numValues: [Int]) -> Bool {
        let uniqueValues = Array(Set(numValues)).sorted()
        if uniqueValues.count < 5 {
            return false
        }
        
        for i in 0..<(uniqueValues.count - 4) {
            if uniqueValues[i] + 4 == uniqueValues[i + 4] {
                return true
            }
        }
        
        // Handle the special case of A-2-3-4-5 straight
        if uniqueValues.suffix(5) == [2, 3, 4, 5, 14] {
            return true
        }
        
        return false
    }

    func findNOfAKind(_ numValues: [Int], n: Int, excluding: Int? = nil) -> Int? {
        let valueCounts = numValues.reduce(into: [Int: Int]()) { counts, value in
            counts[value, default: 0] += 1
        }
        return valueCounts.filter { $0.value == n && $0.key != excluding }.keys.max()
    }
}

struct PlayerCardView: View {
    let card: Card
    
    var body: some View {
        VStack(spacing: 4) {
            Text(card.rank.rawValue)
                .foregroundColor(Color(red: 242/255, green: 130/255, blue: 55/255)) // Use the specific orange color
                .font(.headline)
            
            Text(card.suit.rawValue)
                .foregroundColor(.white) // Keep suit color white
                .font(.headline)
        }
        .frame(width: 50, height: 70)
        .background(Color(red: 51/255, green: 51/255, blue: 57/255))
        .cornerRadius(8)
    }
}

struct CustomCardView: View {
    let card: Card
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black)
                .frame(width: 50, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 31/255, green: 31/255, blue: 37/255), lineWidth: 2)
                )
            
            VStack(spacing: 4) { // Stack rank above suit
                Text(card.rank.rawValue)
                    .foregroundColor(Color(red: 242/255, green: 130/255, blue: 55/255)) // Set rank color to orange
                    .font(.headline)
                
                Text(card.suit.rawValue)
                    .foregroundColor(.white) // Keep suit color white
                    .font(.headline)
            }
        }
    }
}




struct ContentView: View {
    @ObservedObject var pokerTable = PokerTable()
    
    @State private var selectedRank: CardRank?
    @State private var selectedSuit: CardSuit?
    @State private var showCardPicker: Bool = false
    @State private var cardIndex: Int? = nil
    @State private var editingPlayer: Int? = nil
    @State private var showResults: Bool = false
    @State private var selectedCards: [Card] = []
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ScrollView { // ScrollView fix adding players problem
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Text("Equity Calculator")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            .padding(.bottom, 2)
                        
                        Text("Find out if you’re ahead or behind with this pocket equity calculator!")
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                    }
                    .padding()
                    
                    HStack(alignment: .center) {
                        Text("The board")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            ForEach(0..<5, id: \.self) { index in
                                ZStack {
                                    Rectangle()
                                        .foregroundColor(Color(red: 31/255, green: 31/255, blue: 37/255))
                                        .frame(width: 50, height: 70)
                                        .cornerRadius(8)
                                    
                                    if index < pokerTable.communityCards.count {
                                        PlayerCardView(card: pokerTable.communityCards[index])
                                    }
                                }
                                .onTapGesture {
                                    cardIndex = index
                                    editingPlayer = nil
                                    showCardPicker = true
                                    
                                    // Add existing cards on the board to selectedCards when opening the picker
                                    selectedCards = pokerTable.communityCards
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    HStack(alignment: .center) {
                        Text("Player 1")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            ForEach(0..<2, id: \.self) { index in
                                ZStack {
                                    if pokerTable.players.indices.contains(0) && index < pokerTable.players[0].hand.count {
                                        PlayerCardView(card: pokerTable.players[0].hand[index])
                                    } else {
                                        Rectangle()
                                            .foregroundColor(Color(red: 31/255, green: 31/255, blue: 37/255))
                                            .frame(width: 50, height: 70)
                                            .cornerRadius(8)
                                    }
                                }
                                .onTapGesture {
                                    editingPlayer = 0
                                    cardIndex = index
                                    showCardPicker = true
                                    
                                    // Add existing player cards to selectedCards when opening the picker
                                    selectedCards = pokerTable.players[0].hand
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    HStack(alignment: .center) {
                        Text("Villain's cards")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            ForEach(0..<2, id: \.self) { index in
                                ZStack {
                                    if pokerTable.players.indices.contains(1) && index < pokerTable.players[1].hand.count {
                                        PlayerCardView(card: pokerTable.players[1].hand[index])
                                    } else {
                                        Rectangle()
                                            .foregroundColor(Color(red: 31/255, green: 31/255, blue: 37/255))
                                            .frame(width: 50, height: 70)
                                            .cornerRadius(8)
                                    }
                                }
                                .onTapGesture {
                                    editingPlayer = 1
                                    cardIndex = index
                                    showCardPicker = true
                                    
                                    // Add existing player cards to selectedCards when opening the picker
                                    selectedCards = pokerTable.players[1].hand
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    ForEach(pokerTable.players.indices.dropFirst(2), id: \.self) { playerIndex in
                        HStack(alignment: .center) {
                            Text("Player \(playerIndex + 1)'s cards")
                                .foregroundColor(.white)
                                .font(.headline)
                                .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                ForEach(0..<2, id: \.self) { index in
                                    ZStack {
                                        if index < pokerTable.players[playerIndex].hand.count {
                                            PlayerCardView(card: pokerTable.players[playerIndex].hand[index])
                                        } else {
                                            Rectangle()
                                                .foregroundColor(Color(red: 31/255, green: 31/255, blue: 37/255))
                                                .frame(width: 50, height: 70)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .onTapGesture {
                                        editingPlayer = playerIndex
                                        cardIndex = index
                                        showCardPicker = true
                                        
                                        // Add existing player cards to selectedCards when opening the picker
                                        selectedCards = pokerTable.players[playerIndex].hand
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    
                    HStack {
                        Button(action: {
                            pokerTable.addPlayer()
                        }) {
                            HStack {
                                Image(systemName: "person.fill.badge.plus")
                                Text("Add Player")
                            }
                            .padding()
                            .frame(height: 40)
                            .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .cornerRadius(8)
                        .padding(.leading, 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: {
                            pokerTable.calculateOdds()
                            showResults = true
                        }) {
                            HStack {
                                Text("Calculate")
                                Image("CalcIcon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            }
                            .padding()
                            .frame(height: 40)
                            .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .background(Color(red: 242/255, green: 130/255, blue: 55/255))
                        .cornerRadius(8)
                        .padding(.trailing, 0)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    
                    if showResults {
                        ScrollView { //maybe remove because no longer necessay?
                            VStack {
                                HStack {
                                    Spacer()
                                    ForEach(pokerTable.communityCards, id: \.self) { card in
                                        CustomCardView(card: card)
                                    }
                                    Spacer()
                                }
                                .padding(.top, 20)
                                Divider()
                                    .background(Color.white)
                                    .padding(.vertical, 10)
                                
                                ForEach(pokerTable.players.indices, id: \.self) { index in
                                    VStack(alignment: .trailing) {
                                        HStack {
                                            Text(index == 0 ? "You" : index == 1 ? "Villain" : "Player \(index + 1)")
                                                .foregroundColor(.white)
                                                .font(.headline)
                                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                                .padding(.leading, 10)
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 8) {
                                                ForEach(pokerTable.players[index].hand, id: \.self) { card in
                                                    CustomCardView(card: card)
                                                }
                                            }
                                            .padding(.trailing, 10)
                                        }
                                        
                                        if pokerTable.results.indices.contains(index) {
                                            VStack(alignment: .trailing) {
                                                Text("Equity: \(pokerTable.results[index].components(separatedBy: ", Equity ").last ?? "")")
                                                Text("Win: \(pokerTable.results[index].components(separatedBy: "Win ").last?.components(separatedBy: ",").first ?? "")")
                                                Text("Tie: \(pokerTable.results.last?.components(separatedBy: "Tie: ").last ?? "")")
                                            }
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                            .padding(.top, 4)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .padding(.trailing, 10)
                                        }
                                        
                                        Divider()
                                            .background(Color.white)
                                            .padding(.vertical, 10)
                                    }
                                    .padding(.horizontal, 10)
                                }
                            }
                        }
                        .frame(maxHeight: 300) // Limit height of the scroll view
                    }
                    
                    Spacer()
                }
                .padding()
            } // End of ScrollView
        }
        .sheet(isPresented: $showCardPicker) {
            VStack {
                Text("Select Card")
                    .font(.headline)
                    .padding()
                
                HStack {
                    ForEach(selectedCards, id: \.self) { card in
                        Text(card.description)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.gray)
                            .cornerRadius(4)
                    }
                    
                    // Backspace Button
                    Button(action: {
                        if !selectedCards.isEmpty {
                            let removedCard = selectedCards.removeLast()
                            
                            // Remove from player's hand or community cards
                            if let player = editingPlayer {
                                pokerTable.removeCard(from: pokerTable.players[player].id, card: removedCard)
                            } else {
                                pokerTable.removeCommunityCard(card: removedCard)
                            }
                            
                            // Add the card back to the deck
                            pokerTable.deck.append(removedCard)
                        }
                    }) {
                        Image(systemName: "delete.left.fill")
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color(red: 242/255, green: 130/255, blue: 55/255))
                            .cornerRadius(4)
                    }
                    .frame(height: 40)
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(5)
                }
                .padding(.bottom, 10)
                
                // Rank Picker 2-9, T (Three per row)
                VStack(spacing: 10) {
                    ForEach(0..<2) { rowIndex in
                        HStack(spacing: 10) {
                            ForEach(0..<3) { columnIndex in
                                let rank = CardRank.allCases[rowIndex * 3 + columnIndex]
                                Button(action: {
                                    selectedRank = rank
                                    attemptAddCard()
                                }) {
                                    Text(rank.rawValue)
                                        .frame(maxWidth: .infinity, maxHeight: 40)
                                        .background(selectedRank == rank ? Color(red: 242/255, green: 130/255, blue: 55/255) : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        ForEach(6..<9) { index in
                            let rank = CardRank.allCases[index]
                            Button(action: {
                                selectedRank = rank
                                attemptAddCard()
                            }) {
                                Text(rank.rawValue)
                                    .frame(maxWidth: .infinity, maxHeight: 40)
                                    .background(selectedRank == rank ? Color(red: 242/255, green: 130/255, blue: 55/255) : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
                
                // Rank Picker J-Q-K-A (One row, same size as suits)
                HStack(spacing: 10) {
                    ForEach(9..<13) { index in
                        let rank = CardRank.allCases[index]
                        Button(action: {
                            selectedRank = rank
                            attemptAddCard()
                        }) {
                            Text(rank.rawValue)
                                .frame(maxWidth: .infinity, maxHeight: 40)
                                .background(selectedRank == rank ? Color(red: 242/255, green: 130/255, blue: 55/255) : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom, 10)
                
                // Suit Picker
                HStack(spacing: 10) {
                    ForEach(CardSuit.allCases, id: \.self) { suit in
                        Button(action: {
                            selectedSuit = suit
                            attemptAddCard()
                        }) {
                            Text(suit.rawValue.uppercased())
                                .frame(maxWidth: .infinity, maxHeight: 40)
                                .background(selectedSuit == suit ? Color(red: 242/255, green: 130/255, blue: 55/255) : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom, 20)
                
                HStack {
                           // Clear Button
                           Button("Clear") {
                               selectedCards.removeAll() // Clear selected cards
                               
                               // Remove all cards from the current player or the community cards
                               if let player = editingPlayer {
                                   pokerTable.players[player].hand.removeAll()
                               } else {
                                   pokerTable.communityCards.removeAll()
                               }
                           }
                           .frame(height: 30)
                           .font(.system(size: 30, weight: .bold))
                           .padding()
                           .background(Color.gray)
                           .foregroundColor(.white)
                           .cornerRadius(8)
                           .frame(maxWidth: .infinity, alignment: .leading)
                           
                           // Done Button
                           Button("Done") {
                               do {
                                   for card in selectedCards {
                                       if let player = editingPlayer {
                                           try pokerTable.addCard(to: pokerTable.players[player].id, card: card)
                                       } else {
                                           try pokerTable.addCommunityCard(card: card)
                                       }
                                   }
                               } catch {
                                   print("Error adding card: \(error)")
                               }
                               
                               selectedCards.removeAll() // Clear the selected cards after adding them
                               selectedRank = nil
                               selectedSuit = nil
                               showCardPicker = false
                           }
                           .frame(height: 30)
                           .font(.system(size: 30, weight: .bold))
                           .padding()
                           .background(Color(red: 242/255, green: 130/255, blue: 55/255))
                           .foregroundColor(.white)
                           .cornerRadius(8)
                           .frame(maxWidth: .infinity, alignment: .trailing)
                       }
                       .padding(.horizontal)
                       .padding(.bottom, 20)
                   }
                   .padding()
                   .background(Color.black)
               }
    }
    
    private func attemptAddCard() {
        if let rank = selectedRank, let suit = selectedSuit {
            let newCard = Card(rank: rank, suit: suit)
            
            // Check if the new card is already in the selected cards list
            if !selectedCards.contains(newCard) {
                selectedCards.append(newCard)
            }
            
            selectedRank = nil
            selectedSuit = nil
        }
        
        // Now loop through the selected cards and add them as needed
        for card in selectedCards {
            // Check if we are editing the board or a player's hand
            if editingPlayer == nil {
                // Editing the board
                if pokerTable.communityCards.contains(card) {
                    continue // Skip adding if the card is already in the community cards
                }
                
                if pokerTable.communityCards.count < 5 {
                    pokerTable.communityCards.append(card)
                }
            } else {
                // Editing a player's hand
                guard let player = editingPlayer else { return }
                if pokerTable.players[player].hand.contains(card) {
                    continue // Skip adding if the card is already in the player's hand
                }
                
                if pokerTable.players[player].hand.count < 2 {
                    pokerTable.players[player].hand.append(card)
                }
            }
        }
    }
}

extension PokerTable {
    func removeCard(from player: Int, card: Card) {
        if let playerIndex = players.firstIndex(where: { $0.id == player }) {
            players[playerIndex].hand.removeAll { $0 == card }
        }
    }

    func removeCommunityCard(card: Card) {
        communityCards.removeAll { $0 == card }
    }
}

#Preview {
    ContentView()
}
