//
//  ContentView.swift
//  OCR
//
//  Created by WJR on 11/28/23.
//

import SwiftUI
import Vision
import NaturalLanguage
import SQLite3
import SwiftData

struct Quadrilateral {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint
}

struct ContentView: View {
  @State private var image: UIImage? = UIImage(named: "1")
  @State private var textsWords: [[String]] = []
  @State private var linePositions: [CGRect] = []
  @State private var textsRects: [[CGRect]] = []
  
  @State private var midPoints: [CGPoint] = []
  @State private var midLineFunctions: [(slope: Double, intercept: Double)] = []
  @State private var textsPositions: [[Quadrilateral]] = []
  @State private var lineFunctions: [(top: (slope: Double, intercept: Double),
                                      bottom: (slope: Double, intercept: Double))] = []
  
  var body: some View {
    VStack {
      if let image = image {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .overlay(Canvas { context, size in
            for lineRects in textsRects {
              for rect in lineRects {
                let normalizedRect = VNImageRectForNormalizedRect(rect, Int(size.width), Int(size.height))
                context.stroke(Path(normalizedRect), with: .color(.red), lineWidth: 1)
              }
            }
            
//            for linePositions in textsPositions {
//              for position in linePositions {
//                var path = Path()
//                
//                path.move(to: CGPoint(x: position.topLeft.x * size.height, y: position.topLeft.y * size.height))
//                path.addLine(to: CGPoint(x: position.topRight.x * size.height, y: position.topRight.y * size.height))
//                path.addLine(to: CGPoint(x: position.bottomRight.x * size.height, y: position.bottomRight.y * size.height))
//                path.addLine(to: CGPoint(x: position.bottomLeft.x * size.height, y: position.bottomLeft.y * size.height))
//                path.closeSubpath()
//
//                context.stroke(path, with: .color(.green), lineWidth: 1)
//              }
//            }
            
//            for position in linePositions {
//              var path = Path()
//              
//              path.move(to: CGPoint(x: position.minX * size.width, y: (1 - position.maxY) * size.height))
//              path.addLine(to: CGPoint(x: position.maxX * size.width, y: (1 - position.maxY) * size.height))
//              path.addLine(to: CGPoint(x: position.maxX * size.width, y: (1 - position.minY) * size.height))
//              path.addLine(to: CGPoint(x: position.minX * size.width, y: (1 - position.minY) * size.height))
//              path.closeSubpath()
//              
//              context.stroke(path, with: .color(.red), lineWidth: 2)
//            }

//            for lineFunction in lineFunctions {
//              let tSlope = lineFunction.top.slope
//              let bSlope = lineFunction.bottom.slope
//              let tIntercept = lineFunction.top.intercept * Double(size.height)
//              let bIntercept = lineFunction.bottom.intercept * Double(size.height)
//
//              let tX1 = 0.0
//              let tY1 = tSlope * tX1 + tIntercept
//              let tX2 = Double(size.width)
//              let tY2 = tSlope * tX2 + tIntercept
//              
//              let bX1 = 0.0
//              let bY1 = bSlope * bX1 + tIntercept
//              let bX2 = Double(size.width)
//              let bY2 = tSlope * bX2 + bIntercept
//
//              let tPoint1 = CGPoint(x: tX1, y: CGFloat(tY1))
//              let tPpoint2 = CGPoint(x: tX2, y: CGFloat(tY2))
//              
//              let bPoint1 = CGPoint(x: bX1, y: CGFloat(bY1))
//              let bPpoint2 = CGPoint(x: bX2, y: CGFloat(bY2))
//
//              let tPath = Path { path in
//                path.move(to: tPoint1)
//                path.addLine(to: tPpoint2)
//              }
//              let bPath = Path { path in
//                path.move(to: bPoint1)
//                path.addLine(to: bPpoint2)
//              }
//              
//              context.stroke(tPath, with: .color(.blue), lineWidth: 1)
//              context.stroke(bPath, with: .color(.blue), lineWidth: 1)
//            }
          })
      }
      
      Button("Recognize Text") {
        DispatchQueue.global(qos: .userInitiated).async {
          recognizeText(in: image!)
          //start with "sf" means "sentence form"
          let (sfTexts, sfPositions) = formatSentencesAndPositions(textsWords, textsPositions)
        }
      }
    }
  }
}

extension ContentView {
  func recognizeText(in image: UIImage) {
    guard let cgImage = image.cgImage else { return }
    let scale = Double(image.size.width / image.size.height)
    
    let request = VNRecognizeTextRequest { (request, error) in
      guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
        print("Text recognition error: \(error?.localizedDescription ?? "Unknown error")")
        return
      }
      
      for observation in observations {
        guard let topCandidate = observation.topCandidates(1).first else { continue }
        
        
        var lineWords: [String] = []
        var lineRects: [CGRect] = []
        
        var lineBoundingBoxs: [CGRect] = []
        
        linePositions.append(observation.boundingBox)
        for (index, character) in topCandidate.string.enumerated() {
          let startIndex = topCandidate.string.index(topCandidate.string.startIndex, offsetBy: index)
          let endIndex = topCandidate.string.index(startIndex, offsetBy: 1)
          
          let range = startIndex..<endIndex
          
          if let wordBox = try? topCandidate.boundingBox(for: range) {
            let boundingBox = wordBox.boundingBox
            if character != " " {
              if boundingBox != lineBoundingBoxs.last {
                lineWords.append("")
                lineBoundingBoxs.append(boundingBox)
                let rect = CGRect(x: boundingBox.minX, y: 1 - boundingBox.minY - boundingBox.height, width: boundingBox.width, height: boundingBox.height)
                lineRects.append(rect)
              }
              lineWords[lineWords.count - 1] += String(character)
            }
          }
        }
        
        if !textsWords.contains(lineWords) {
          print(lineWords)
          let midPoints = lineRects.map { rect in
            return CGPoint(x: Double(rect.midX) * scale, y: Double(rect.midY))
          }
          let midLineFunction = performLinearRegression(on: midPoints)
          
          var linePositions: [Quadrilateral] = []
          var topPoints: [CGPoint] = []
          var bottomPoints: [CGPoint] = []
          
          var topLineFunction: (slope: Double, intercept: Double)
          var bottomLineFunction: (slope: Double, intercept: Double)
          
          if midLineFunction.slope >= 0.0 {
            for i in 0 ..< lineRects.count - 1 {
              let currentRect = lineRects[i]
              let nextRect = lineRects[i + 1]
              
              let currentTopRight = CGPoint(x: currentRect.maxX * scale, y: currentRect.minY)
              let currentBottomRight = CGPoint(x: currentRect.maxX * scale, y: currentRect.maxY)
              let currentBottomLeft = CGPoint(x: currentRect.minX * scale, y: currentRect.maxY)
              
              let nextTopRight = CGPoint(x: nextRect.maxX * scale, y: nextRect.minY)
              let nextTopLeft = CGPoint(x: nextRect.minX * scale, y: nextRect.minY)
              let nextBottomLeft = CGPoint(x: nextRect.minX * scale, y: nextRect.maxY)
              
              topPoints.append(points_intersection(currentTopRight, currentBottomRight, nextTopLeft, nextTopRight)!)
              bottomPoints.append(points_intersection(currentBottomLeft, currentBottomRight, nextTopLeft, nextBottomLeft)!)
            }
          } else {
            for i in 0 ..< lineRects.count - 1 {
              let currentRect = lineRects[i]
              let nextRect = lineRects[i + 1]
              
              let currentTopLeft = CGPoint(x: currentRect.minX * scale, y: currentRect.minY)
              let currentTopRight = CGPoint(x: currentRect.maxX * scale, y: currentRect.minY)
              let currentBottomRight = CGPoint(x: currentRect.maxX * scale, y: currentRect.maxY)
              
              let nextTopLeft = CGPoint(x: nextRect.minX * scale, y: nextRect.minY)
              let nextBottomLeft = CGPoint(x: nextRect.minX * scale, y: nextRect.maxY)
              let nextBottomRight = CGPoint(x: nextRect.maxX * scale, y: nextRect.maxY)
              
              topPoints.append(points_intersection(currentTopLeft, currentTopRight, nextTopLeft, nextBottomLeft)!)
              bottomPoints.append(points_intersection(currentTopRight, currentBottomRight, nextBottomLeft, nextBottomRight)!)
            }
          }
          topLineFunction = performLinearRegression(on: topPoints)
          bottomLineFunction = performLinearRegression(on: bottomPoints)
          print(midLineFunction)
          
          if midLineFunction.slope.isInfinite {
            lineFunctions.append((top: bottomLineFunction, bottom: topLineFunction))
            
            linePositions = lineRects.map{Quadrilateral(topLeft: CGPoint(x: $0.minX * scale, y: $0.maxY),
                                                        topRight: CGPoint(x: $0.minX * scale, y: $0.minY),
                                                        bottomLeft: CGPoint(x: $0.maxX * scale, y: $0.maxY),
                                                        bottomRight: CGPoint(x: $0.maxX * scale, y: $0.minY))}
          } else if abs(midLineFunction.slope) <= 0.02 {
            lineFunctions.append((top: topLineFunction, bottom: bottomLineFunction))
            
            linePositions = lineRects.map{Quadrilateral(topLeft: CGPoint(x: $0.minX * scale, y: $0.minY),
                                                        topRight: CGPoint(x: $0.maxX * scale, y: $0.minY),
                                                        bottomLeft: CGPoint(x: $0.minX * scale, y: $0.maxY),
                                                        bottomRight:  CGPoint(x: $0.maxX * scale, y: $0.maxY))}
          } else {
            lineFunctions.append((top: topLineFunction, bottom: bottomLineFunction))
            
            linePositions = []
            
            for i in 0 ..< lineRects.count {
              let rect = lineRects[i]
              
              let topside = (slope: 0.0, intercept: Double(rect.minY))
              let bottomside = (slope: 0.0, intercept: Double(rect.maxY))
              let leftside = (slope: Double.infinity, intercept: Double(rect.minX * scale))
              let rightside = (slope: Double.infinity, intercept: Double(rect.maxX * scale))
              
              var topLeftIntersection1: CGPoint?
              var topLeftIntersection2: CGPoint?
              var bottomLeftIntersection1: CGPoint?
              var bottomLeftIntersection2: CGPoint?
              var topRightIntersection1: CGPoint?
              var topRightIntersection2: CGPoint?
              var bottomRightIntersection1: CGPoint?
              var bottomRightIntersection2: CGPoint?
              
              if midLineFunction.slope < 0 {
                topLeftIntersection1 = lineFunctions_intersection(topLineFunction, leftside)
                topLeftIntersection2 = lineFunctions_intersection(topLineFunction, bottomside)
                bottomLeftIntersection1 = lineFunctions_intersection(topLineFunction, leftside)
                bottomLeftIntersection2 = lineFunctions_intersection(topLineFunction, bottomside)
                
                topRightIntersection1 = lineFunctions_intersection(bottomLineFunction, topside)
                topRightIntersection2 = lineFunctions_intersection(bottomLineFunction, rightside)
                bottomRightIntersection1 = lineFunctions_intersection(bottomLineFunction, topside)
                bottomRightIntersection2 = lineFunctions_intersection(bottomLineFunction, rightside)
              } else {
                topLeftIntersection1 = lineFunctions_intersection(topLineFunction, topside)
                topLeftIntersection2 = lineFunctions_intersection(topLineFunction, leftside)
                bottomLeftIntersection1 = lineFunctions_intersection(bottomLineFunction, topside)
                bottomLeftIntersection2 = lineFunctions_intersection(bottomLineFunction, leftside)
                
                topRightIntersection1 = lineFunctions_intersection(topLineFunction, rightside)
                topRightIntersection2 = lineFunctions_intersection(topLineFunction, bottomside)
                bottomRightIntersection1 = lineFunctions_intersection(bottomLineFunction, rightside)
                bottomRightIntersection2 = lineFunctions_intersection(bottomLineFunction, bottomside)
              }
              
              let topLeftLineIntersection = topLeftIntersection1?.x ?? 0 > topLeftIntersection2?.x ?? 0 ? topLeftIntersection1 : topLeftIntersection2
              let bottomLeftLineIntersection = bottomLeftIntersection1?.x ?? 0 > bottomLeftIntersection2?.x ?? 0 ? bottomLeftIntersection1 : bottomLeftIntersection2
              let topRightIntersection = topRightIntersection1?.x ?? 2 < topRightIntersection2?.x ?? 2 ? topRightIntersection1 : topRightIntersection2
              let bottomRightIntersection = bottomRightIntersection1?.x ?? 2 < bottomRightIntersection2?.x ?? 2 ? bottomRightIntersection1 : bottomRightIntersection2
              
              let leftCenterPoint = CGPoint(x: (topLeftLineIntersection!.x + bottomLeftLineIntersection!.x) / 2,
                                            y: (topLeftLineIntersection!.y + bottomLeftLineIntersection!.y) / 2)
              let rightCenterPoint = CGPoint(x: (topRightIntersection!.x + bottomRightIntersection!.x) / 2,
                                             y: (topRightIntersection!.y + bottomRightIntersection!.y) / 2)
              
              let topLeftPoint = perpendicular_intersection(lineFunction: topLineFunction, center: leftCenterPoint)!
              let bottomLeftPoint = perpendicular_intersection(lineFunction: bottomLineFunction, center: leftCenterPoint)!
              let topRightPoint = perpendicular_intersection(lineFunction: topLineFunction, center: rightCenterPoint)!
              let bottomRightPoint = perpendicular_intersection(lineFunction: bottomLineFunction, center: rightCenterPoint)!
              
              linePositions.append(Quadrilateral(topLeft: topLeftPoint, topRight: bottomLeftPoint, bottomLeft: topRightPoint, bottomRight: bottomRightPoint))
            }
          }
          textsRects.append(lineRects)
          textsWords.append(lineWords)
          textsPositions.append(linePositions)
        }
      }
    }
    request.recognitionLevel = .accurate
    
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try? handler.perform([request])
  }
  
  func formatSentencesAndPositions(_ words: [[String]], _ positions: [[Quadrilateral]]) -> ([[String]], [[[Quadrilateral]]]) {
    var originalWords: [[String]] = words
    var originalPositions: [[Quadrilateral]] = positions
    let endSymbols = Set([".", "?", "!", ";"])
    var formattedWords: [[String]] = []
    var formattedPositions: [[[Quadrilateral]]] = []
    
    var currentSentenceWords: [String] = []
    var currentSentencePositions: [[Quadrilateral]] = []
    
    func addNewLine() {
      formattedWords.append(currentSentenceWords)
      formattedPositions.append(currentSentencePositions)
      currentSentenceWords.removeAll()
      currentSentencePositions.removeAll()
    }
    
    for lineIndex in 0 ..< originalWords.count {
      for wordIndex in 0 ..< originalWords[lineIndex].count {
        var word = originalWords[lineIndex][wordIndex]
        let position = originalPositions[lineIndex][wordIndex]
        
        if wordIndex == originalWords[lineIndex].count - 1 && word.hasSuffix("-") && lineIndex < originalWords.count - 1 {
          let nextLineFirstWord: String = originalWords[lineIndex + 1].first!
          let nextLineFirstPosition: Quadrilateral = originalPositions[lineIndex + 1].first!
          
          currentSentenceWords.append(String(word.dropLast() + nextLineFirstWord))
          currentSentencePositions.append([position, nextLineFirstPosition])
          
          word = nextLineFirstWord
          originalWords[lineIndex + 1].removeFirst()
          originalPositions[lineIndex + 1].removeFirst()
        } else {
          currentSentenceWords.append(word)
          currentSentencePositions.append([position])
        }
        
        
        if endSymbols.contains(where: word.hasSuffix) {
          if word.hasSuffix(".") {
            if word.filter({ $0 == "." }).count == 1 &&
                (word.count >= 3 && !(word[word.index(word.endIndex, offsetBy: -2)].isLowercase && word[word.index(word.endIndex, offsetBy: -3)].isUppercase) ||
                 word.count == 2 && !(word[word.index(word.endIndex, offsetBy: -2)].isUppercase)) {
              addNewLine()
            }
          } else {
            addNewLine()
          }
        }
      }
      
      if !currentSentenceWords.isEmpty {
        if lineIndex < originalWords.count - 1 {
          let currentLineFunction = lineFunctions[lineIndex]
          let nextLineFunction = lineFunctions[lineIndex + 1]
          
          var currentLineY: (top: Double, bottom: Double)
          var nextLineY: (top: Double, bottom: Double)
          
          if currentLineFunction.top.slope.isInfinite {
            currentLineY = (top: currentLineFunction.top.intercept,
                            bottom: currentLineFunction.bottom.intercept)
            nextLineY = (top: nextLineFunction.top.intercept,
                         bottom: nextLineFunction.bottom.intercept)
          } else {
            currentLineY = (top: currentLineFunction.top.intercept * 0.2 + currentLineFunction.top.intercept,
                            bottom: currentLineFunction.bottom.intercept * 0.2 + currentLineFunction.bottom.intercept)
            nextLineY = (top: nextLineFunction.top.intercept * 0.2 + nextLineFunction.top.intercept,
                         bottom: nextLineFunction.bottom.intercept * 0.2 + nextLineFunction.bottom.intercept)
          }
          let currentLineHeight = abs(currentLineY.bottom - currentLineY.top)
          let nextLineHeight = abs(nextLineY.bottom - nextLineY.top)
          let linesSpacing = abs(nextLineY.top - currentLineY.bottom)
          let averageLineHeight = (currentLineHeight + nextLineHeight) / 2
          
          let lineSpacingScale = linesSpacing / averageLineHeight
          let heightDifferenceScale = abs(currentLineHeight - nextLineHeight) / averageLineHeight
          print("lineSpacingScale: \(lineSpacingScale)")
          print("heightDifferenceScale: \(heightDifferenceScale)")
          
          if lineSpacingScale > 0.7 || heightDifferenceScale > 0.35 {
            addNewLine()
          }
        } else {
          addNewLine()
        }
      }
    }
    
    return (formattedWords, formattedPositions)
  }
}
/*
  func formatWords(for sentences: [[String]]) -> ([[[String]]], [[[String]]]) {
    var allWords = [[[String]]]()
    var allTags = [[[String]]]()
    
    for (_, sentence) in sentences.enumerated() {
      var currentLineWords: [[String]] = [[]]
      var currentLineTags: [[String]] = [[]]
      
      let text = sentence.joined(separator: " ")
      let tagger = NLTagger(tagSchemes: [.lexicalClass, ])
      tagger.string = text
      
      tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
        if let tag = tag?.rawValue {
          if tag == "Whitespace" {
            currentLineWords.append([])
            currentLineTags.append([])
          } else {
            let wordsPOS = Set(["Noun", "Verb", "Adjective", "Adverb", "Pronoun", "Determiner", "Particle", "Preposition", "Number", "Conjunction", "Interjection", "Classifier", "Idiom", "OtherWord"])
            if wordsPOS.contains(tag) {
              let specificWords = ["\'s", "\'re"]
              let originalWord = String(text[tokenRange])
              if !specificWords.contains(originalWord) {
                var lemmaWord = ""
                
                let taggerL = NLTagger(tagSchemes: [.lemma])
                taggerL.string = originalWord
                let (lemma, _) = taggerL.tag(at: originalWord.startIndex, unit: .word, scheme: .lemma)
                if let lemma = lemma {
                  lemmaWord = lemma.rawValue
                } else {
                  lemmaWord = originalWord
                }
                
                currentLineWords[currentLineWords.count - 1].append(lemmaWord)
                currentLineTags[currentLineTags.count - 1].append(tag)
              }
            }
          }
        }
        return true
      }
      allWords.append(currentLineWords)
      allTags.append(currentLineTags)
    }
    
    return (allWords, allTags)
  }
  
  func removeExistingWords(_ words: [[String]], _ positions: [[Quadrilateral]], _ POSs: [[String]], completion: @escaping ([[String]], [[Quadrilateral]]) -> Void) {
    let queue = DispatchQueue(label: "com.example.myqueue")
    let lemmatizer = CustomWordNetLemmatizer()
    queue.async {
      var db: OpaquePointer?
      
      guard let path = Bundle.main.path(forResource: "wordFreq", ofType: "db") else {
        print("Database file not found in the app bundle")
        return
      }
      
      if sqlite3_open(path, &db) != SQLITE_OK {
        print("Error opening database")
        return
      }
      
      var wordString = ""
      for (i, vocabulary) in words.enumerated() {
        for (j, word) in vocabulary.enumerated() {
          //Lemmatization words
          var pos = lemmatizer.ADJ_SAT
          switch POSs[i][j] {
          case "Noun":
            pos = lemmatizer.NOUN
          case "Adverb":
            pos = lemmatizer.ADV
          case "Adjective":
            pos = lemmatizer.ADJ
          case "Verb":
            pos = lemmatizer.VERB
          default:
            pos = lemmatizer.ADJ_SAT
          }
          let finalWord = lemmatizer.morphy(form: word, pos: pos).last!.lowercased()
          wordString += "\"\(finalWord)\","
        }
      }
      
      wordString = String(wordString.dropLast())
      
      var queryStatement: OpaquePointer?
      let queryStatementString = "SELECT word FROM WordFreq WHERE id <= 3999 AND word IN (\(wordString));"
      
      if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
        var existingWords: Set<String> = []
        while sqlite3_step(queryStatement) == SQLITE_ROW {
          if let cString = sqlite3_column_text(queryStatement, 0) {
            let word = String(cString: cString)
            existingWords.insert(word)
          }
        }
        
        sqlite3_finalize(queryStatement)
        
        var filteredTexts: [[String]] = []
        var filteredRects: [[Quadrilateral]] = []
        
        for (i, vocabulary) in words.enumerated() {
          var currentVocabularyWords = [String]()
          var currentVocabularyPositions = [Quadrilateral]()
          for (j, word) in vocabulary.enumerated() {
            //Lemmatization words
            var pos = lemmatizer.ADJ_SAT
            switch POSs[i][j] {
            case "Noun":
              pos = lemmatizer.NOUN
            case "Adverb":
              pos = lemmatizer.ADV
            case "Adjective":
              pos = lemmatizer.ADJ
            case "Verb":
              pos = lemmatizer.VERB
            default:
              pos = lemmatizer.ADJ_SAT
            }
            //Lemmatization words
            
            let finalWord = lemmatizer.morphy(form: word, pos: pos).last!.lowercased()
            if !existingWords.contains(finalWord) {
              currentVocabularyWords.append(word)
              currentVocabularyPositions.append(positions[i][j])
            }
          }
          filteredTexts.append(currentVocabularyWords)
          filteredRects.append(currentVocabularyPositions)
        }
        
        DispatchQueue.main.async {
          completion(filteredTexts, filteredRects)
        }
      } else {
        print("Error preparing query: \(String(cString: sqlite3_errmsg(db)))")
      }
      
      sqlite3_close(db)
    }
  }
  
  func findDefinitions(_ originalWords: [[String]]) -> [String: String] {
    var db: OpaquePointer?
    var results = [String: String]()
    var wordGroups = [String: [String]]()
    let words = originalWords.flatMap { $0 }
    
    guard let path = Bundle.main.path(forResource: "dictionary", ofType: "db") else {
      print("Database file not found")
      return results
    }
    
    if sqlite3_open(path, &db) != SQLITE_OK {
      print("Error opening database")
      return results
    }
    
    for word in words {
      let initial = String(word.first?.lowercased() ?? "_").rangeOfCharacter(from: CharacterSet.letters) == nil ? "SPECIAL_Words" : word.first!.uppercased() + "_Words"
      wordGroups[initial, default: []].append(word)
    }
    
    for (initial, groupWords) in wordGroups {
      let placeholders = groupWords.map { _ in "word COLLATE NOCASE = ?" }.joined(separator: " OR ")
      let queryString = "SELECT word, translation FROM \(initial) WHERE \(placeholders)"
      var statement: OpaquePointer?
      
      if sqlite3_prepare_v2(db, queryString, -1, &statement, nil) == SQLITE_OK {
        for (index, word) in groupWords.enumerated() {
          let utf8Word = strdup(word)
          sqlite3_bind_text(statement, Int32(index + 1), utf8Word, -1, free)
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
          let word = String(cString: sqlite3_column_text(statement, 0))
          let translation = String(cString: sqlite3_column_text(statement, 1))
          results[word] = translation
        }
        sqlite3_finalize(statement)
      } else {
        print("SELECT statement could not be prepared")
      }
    }
    
    if sqlite3_close(db) != SQLITE_OK {
      let errorMessage = String(cString: sqlite3_errmsg(db))
      print("Error closing database: \(errorMessage)")
    }
    
    print(results.count)
    return results
  }
}
 */
func performLinearRegression(on points: [CGPoint]) -> (slope: Double, intercept: Double) {
  let n = Double(points.count)
  let sumX = points.reduce(0) { $0 + $1.x }
  let sumY = points.reduce(0) { $0 + $1.y }
  let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
  let sumX2 = points.reduce(0) { $0 + $1.x * $1.x }

  let denominator = n * sumX2 - sumX * sumX
  guard denominator != 0 else {
      return (Double.infinity, 0)
  }

  let xMin = points.map { $0.x }.min() ?? 0
  let xMax = points.map { $0.x }.max() ?? 0
  let xRange = xMax - xMin
  
  var slope = (n * sumXY - sumX * sumY) / denominator

  if xRange < 0.001 || abs(slope) > 150 {
    return (Double.infinity, xMin)
  } else {
    slope = round(slope * 1_000_0) / 1_000_0

  }

  let intercept = (sumY - slope * sumX) / n

  return (slope, intercept)
}

                               
func points_lineFunction(_ p1: CGPoint, _ p2: CGPoint) -> (slope: Double, intercept: Double) {
  if p1.x == p2.x {
    return (Double.infinity, Double(p1.x))
  } else {
    let slope = (p2.y - p1.y) / (p2.x - p1.x)
    let intercept = p1.y - slope * p1.x
    return (slope, intercept)
  }
}

func lineFunctions_intersection(_ l1: (slope: Double, intercept: Double), _ l2: (slope: Double, intercept: Double)) -> CGPoint? {
  let (slope1, intercept1) = l1
  let (slope2, intercept2) = l2

  if slope1 == Double.infinity {
    let x = intercept1
    let y = slope2 * x + intercept2
    return CGPoint(x: x, y: y)
  } else if slope2 == Double.infinity {
    let x = intercept2
    let y = slope1 * x + intercept1
    return CGPoint(x: x, y: y)
  } else if slope1 == slope2 {
    return nil
  } else {
    let x = (intercept2 - intercept1) / (slope1 - slope2)
    let y = slope1 * x + intercept1
    return CGPoint(x: x, y: y)
  }
}

func points_intersection(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
  return lineFunctions_intersection(points_lineFunction(p1, p2), points_lineFunction(p3, p4))
}

func perpendicular_intersection(lineFunction: (slope: Double, intercept: Double), center: CGPoint) -> CGPoint? {
  if lineFunction.slope.isInfinite {
    return CGPoint(x: lineFunction.intercept, y: center.y)
  } else if lineFunction.slope == 0 {
    return CGPoint(x: center.x, y: lineFunction.intercept)
  } else {
    let perpendicularSlope: Double = -1 / lineFunction.slope
    let interceptPerpendicular: Double = center.y - perpendicularSlope * center.x
    let perpendicularLineFunction = (slope: perpendicularSlope, intercept: interceptPerpendicular)

    return lineFunctions_intersection(lineFunction, perpendicularLineFunction)
  }
}
/*
class CustomWordNetLemmatizer {
    let ADJ = "a", ADJ_SAT = "s", ADV = "r", NOUN = "n", VERB = "v"
    var morphologicalSubstitutions: [String: [(String, String)]]
    var exceptionMap: [String: [String: [String]]]

    init() {
        morphologicalSubstitutions = [
            NOUN: [("s", ""), 
                   ("ses", "s"),
                   ("ves", "f"),
                   ("xes", "x"),
                   ("zes", "z"),
                   ("ches", "ch"),
                   ("shes", "sh"),
                   ("men", "man"),
                   ("ies", "y")],
            VERB: [("s", ""), 
                   ("ies", "y"),
                   ("es", "e"),
                   ("es", ""),
                   ("ed", "e"),
                   ("ed", ""),
                   ("ing", "e"),
                   ("ing", "")],
            ADJ: [("er", ""),
                  ("est", ""),
                  ("er", "e"),
                  ("est", "e")],
            ADV: []
        ]
        exceptionMap = [:]
        loadExceptionMap()
    }

  private func loadExceptionMap() {
    let fileMap = [ADJ: "adj", ADV: "adv", NOUN: "noun", VERB: "verb"]
    for (pos, suffix) in fileMap {
      if let filePath = Bundle.main.path(forResource: suffix, ofType: "exc") {
        if let content = try? String(contentsOfFile: filePath) {
          for line in content.components(separatedBy: "\n") {
            let terms = line.split(separator: " ").map(String.init)
            if terms.count > 1 {
              exceptionMap[pos, default: [:]][terms[0]] = Array(terms.dropFirst())
            }
          }
        }
      }
    }
  }

  func morphy(form: String, pos: String) -> [String] {
    if let exceptions = exceptionMap[pos]?[form] {
      return exceptions
    }
    
    let substitutions = morphologicalSubstitutions[pos, default: []]
    let forms = substitutions.compactMap { old, new -> String? in
      if form.hasSuffix(old) {
        return String(form.dropLast(old.count)) + new
      }
      return nil
    }
    
    return [form] + forms
  }
}

#Preview {
  ContentView()
}
*/

