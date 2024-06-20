# GitFeed-RxSwift
[![en](https://img.shields.io/badge/lang-en-red.svg)](https://github.com/JustinInCoding/GitFeed-RxSwift/blob/master/README.md)
[![zh-cn](https://img.shields.io/badge/lang-zh--cn-blue.svg)](https://github.com/JustinInCoding/GitFeed-RxSwift/blob/master/README.zh-cn.md)

> This project is for me to learn from kodeco's iOS courses. Here I try to grasp the knowledge of RxSwift by recording the steps of transform a normal Swift App into an RxSwift app.

## Features
- fetch data from GitHub's JSON API, convert it to data and display on list
- persist data into disk to display before fetch from the Github's latest data

## Technologies Used
- 


## Screenshots/Design
- [HIG-Foundations-Typography-Specifications](https://developer.apple.com/design/human-interface-guidelines/typography#Specifications)
<!-- ![Example screenshot](./img/screenshot.png) -->


## Setup
Xcode - 13.2.1 (the version I created the project)

## Tips and Learned
- flatMap
    - You can flatten observables that instantly emit elements and complete, such as the Observable instances you create out of arrays of strings or numbers
    - You can flatten observables that perform some asynchronous work and effectively “wait” for the observable to complete, and only then let the rest of the chain continue working
- share() vs. share(replay: 1)
    - URLSession.rx.response(request:) sends your request to the server, and upon receiving the response, emits a .next event just once with the returned data, and then completes
    - In this situation, if the observable completes and then you subscribe to it again, that will create a new subscription and will fire another identical request to the server.
    - To prevent situations like this, you use share(replay:scope:). This operator keeps a buffer of the last replay elements emitted and feeds them to any newly subscribed observers. Therefore, if your request has completed and a new observer subscribes to the shared sequence (via share(replay:scope:)), it will immediately receive the buffered response from the previously-executed network request.
    - .whileConnected(default) and .forever
        - The former will buffer elements up to the point where it has no subscribers, and the latter will keep the buffered elements forever. That sounds nice, but consider the implications on how much memory is used by the app.
        - .forever: the buffered network response is kept forever. New subscribers get the buffered response.
        - .whileConnected: the buffered network response is kept until there are no more subscribers, and is then discarded. New subscribers get a fresh network response
    - The rule of thumb for using share(replay:scope:) is to use it on any sequences you expect to complete, or ones that cause a heavy workload and are subscribed to multiple times; this way you prevent the observable from being re-created for any additional subscriptions.
    - You can also use this if you’d like new observers to automatically receive the last n emitted events.

## Acknowledgements
Thanks for the kodeco's team providing such a great course
- Original Repository of Kodeco [_here_](). 

