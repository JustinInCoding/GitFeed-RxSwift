/// Copyright (c) 2024
/// GitFeed-RxSwift
/// JustinWang    
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import UIKit
import RxSwift
import RxRelay
import RxCocoa
import Kingfisher

func cachedFileURL(_ fileName: String) -> URL {
  return FileManager.default
    .urls(for: .cachesDirectory, in: .allDomainsMask)
    .first!
    .appendingPathComponent(fileName)
}

class ActivityController: UITableViewController {
  private let repo = "ReactiveX/RxSwift"
  
  private let events = BehaviorRelay<[Event]>(value: [])
  private let bag = DisposeBag()
  
  private let eventsFileURL = cachedFileURL("events.json")
  
  private let modifiedFileURL = cachedFileURL("modified.txt")
  private let lastModified = BehaviorRelay<String?>(value: nil)
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = repo
    
    self.refreshControl = UIRefreshControl()
    let refreshControl = self.refreshControl!
    
    refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
    refreshControl.tintColor = UIColor.darkGray
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to Refresh")
    refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
    
    // load persisted events on screen instantly before fetch the latest on server
    let decoder = JSONDecoder()
    if let eventsData = try? Data(contentsOf: eventsFileURL),
       let persistedEvents = try? decoder.decode([Event].self, from: eventsData) {
      events.accept(persistedEvents)
    }
    
    if let lastModifiedString = try? String(contentsOf: modifiedFileURL, encoding: .utf8) {
      lastModified.accept(lastModifiedString)
    }
    
    refresh()
  }
  
  @objc func refresh() {
    DispatchQueue.global(qos: .default).async { [weak self] in
      guard let self = self else { return }
      self.fetchEvents(repo: self.repo)
    }
  }
  
  func fetchEvents(repo: String) {
    let response = Observable.from(["https://api.github.com/search/repositories?q=language:swift&per_page=5"])
      .map { urlString -> URL in
        return URL(string: urlString)!
      }
      .map { url -> URLRequest in
        return URLRequest(url: url)
      }
    // flatten observables that perform some asynchronous work and effectively “wait” for the observable to complete, and only then let the rest of the chain continue working
      .flatMap { request -> Observable<Any> in
        return URLSession.shared.rx.json(request: request)
      }
      .flatMap { response -> Observable<String> in
        guard let response = response as? [String: Any],
              let items = response["items"] as? [[String: Any]] else {
                return Observable.empty()
              }
        
        return Observable.from(items.map { $0["full_name"] as! String })
      }
      .map { urlString -> URL in
        return URL(string: "https://api.github.com/repos/\(urlString)/events")!
      }
      .map { [weak self] url -> URLRequest in
        var request = URLRequest(url: url)
        // This extra header tells GitHub that you aren’t interested in any events older than the header date
        if let modifiedHeader = self?.lastModified.value {
          request.addValue(modifiedHeader, forHTTPHeaderField: "Last-Modified")
        }
        return request
      }
      // flatten observables that perform some asynchronous work and effectively “wait” for the observable to complete, and only then let the rest of the chain continue working
      .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
        return URLSession.shared.rx.response(request: request)
      }
      .share(replay: 1)
    
    response
      .filter { response, _ in
        // What’s with that pesky, built-in ~= operator? It’s one of the lesser-known Swift operators, and when used with a range on its left side, checks if the range includes the value on its right side
        return 200..<300 ~= response.statusCode
      }
    // discard the response object and take only the response data
      .compactMap { _, data -> [Event]? in
        // create a JSONDecoder and attempt to decode the response data as an array of Events.
        // use a try? to return a nil value in case the decoder throws an error while decoding the JSON data
        return try? JSONDecoder().decode([Event].self, from: data)
      }
      .subscribe(
        onNext: { [weak self] newEvents in
          self?.processEvents(newEvents)
        }
      )
      .disposed(by: bag)
    
    response
      .filter { response, _ in
        return 200..<400 ~= response.statusCode
      }
    // return an Observable<String> with a single element; otherwise, you return an Observable, which never emits any elements
      .flatMap { response, _ -> Observable<String> in
        guard let value = response.allHeaderFields["Last-Modified"] as? String else {
          return Observable.empty()
        }
        return Observable.just(value)
      }
      .subscribe(
        onNext: { [weak self] modifiedHeader in
          guard let self = self else { return }

          self.lastModified.accept(modifiedHeader)
          try? modifiedHeader.write(to: self.modifiedFileURL, atomically: true, encoding: .utf8)
        }
      )
      .disposed(by: bag)
    
    // Challenge
//    let response = Observable.from(["https://api.github.com/search/repositories?q=language:swift&per_page=5"])
//      .map { urlString -> URL in
//        return URL(string: urlString)!
//      }
//      .map { url -> URLRequest in
//        return URLRequest(url: url)
//      }
//      // flatten observables that perform some asynchronous work and effectively “wait” for the observable to complete, and only then let the rest of the chain continue working
//      .flatMap { request -> Observable<Any> in
//        return URLSession.shared.rx.json(request: request)
//      }
//      .flatMap { response -> Observable<String> in
//        guard let response = response as? [String: Any],
//              let items = response["items"] as? [[String: Any]] else {
//                return Observable.empty()
//              }
//
//        return Observable.from(items.map { $0["full_name"] as! String })
//      }
    
    
  }
  
  func processEvents(_ newEvents: [Event]) {
    var updatedEvents = newEvents + events.value
    if updatedEvents.count > 50 {
      updatedEvents = [Event](updatedEvents.prefix(upTo: 50))
    }
    events.accept(updatedEvents)
    // workaround to operate UI in main thread
    DispatchQueue.main.async {
      self.tableView.reloadData()
      // hide the refresh control
      self.refreshControl?.endRefreshing()
    }
    
    let encoder = JSONEncoder()
    if let eventData = try? encoder.encode(updatedEvents) {
      // .atomicWrite An option that attempts to write data to an auxiliary(辅助的；备用的，后备的) file first and then exchange the files
      // Use atomic instead
      // .atomic An option to write data to an auxiliary file first and then replace the original file with the auxiliary file when the write completes.
      try? eventData.write(to: eventsFileURL, options: .atomic)
    }
  }
  
  // MARK: - Table Data Source
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return events.value.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let event = events.value[indexPath.row]
    
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = event.actor.name
    cell.detailTextLabel?.text = event.repo.name + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
    cell.imageView?.kf.setImage(with: event.actor.avatar, placeholder: UIImage(named: "blank-avatar"))
    return cell
  }
  
}
