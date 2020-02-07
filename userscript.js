// ==UserScript==
// @name     Twitter Archiver
// @version  1
// @grant    none
// @namespace https://twitter.com
// @include https://twitter.com/*
// ==/UserScript==


// TODO guard against invalid last tweets (photos?)
// TODO "2 more replies" issue (maybe not a real issue?) auto-expand them somehow?
// TODO only run it on pages with actual threads

var intervals = {}

function getLastXPath(xpexp) {
  let iterator = document.evaluate(xpexp, document, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE, null);
  
  var result = iterator.iterateNext();
  var lastEl = result;

  while(result != null) {
    result = iterator.iterateNext();
    
    if (result == null) {
      break;
    }
    lastEl = result;
  }
  return lastEl;
}

function getLastTweet() {
  let author = window.location.pathname.split('/')[1];
  let xp = `//a[contains(@href, '${author}/status')]`;
  
  return getLastXPath(xp).href;
}

function getTopTweet() {
  let xp = "//span[text()='Thread']";
  return getLastXPath(xp);
}

function appendButton() {
  if (!window.location.pathname.includes("/status")) {
    clearInterval(intervals["appendButton"])
    return;
  }
  
  var buttonEl = document.getElementById("twitblog");
  
  if (buttonEl) {
    console.log(buttonEl);
    clearInterval(intervals["appendButton"])
    return;
  }
  
  console.log("Trying to append the button");
  let topTweet = getTopTweet();
  
  if (!topTweet) {
    // TODO needs to work on all pages with "status" in it
    return;
  }
  
  let button = document.createElement("button");
  button.textContent = "Save Tweet";
  button.id = "twitblog";

  button.addEventListener("click", ev => { alert(getLastTweet()); });
  topTweet.appendChild(button);

  buttonAdded = true;
  clearInterval(intervals["appendButton"])
}

window.addEventListener('DOMContentLoaded', (event) => {
  console.log('DOM fully loaded and parsed');
  
    /* https://stackoverflow.com/questions/6390341/how-to-detect-url-change-in-javascript */
  history.pushState = ( f => function pushState() {
      var ret = f.apply(this, arguments);
      window.dispatchEvent(new Event('pushstate'));
      window.dispatchEvent(new Event('locationchange'));
      return ret;
  })(history.pushState);

  history.replaceState = ( f => function replaceState() {
      var ret = f.apply(this, arguments);
      window.dispatchEvent(new Event('replacestate'));
      window.dispatchEvent(new Event('locationchange'));
      return ret;
  })(history.replaceState);

  window.addEventListener('popstate',() => {
      window.dispatchEvent(new Event('locationchange'))
  });
  
  window.addEventListener('locationchange', function() {
    console.log("Location changed");
    if (window.location.pathname.includes("/status")) {
      console.log('location changed!');
    	buttonAdded = false;
    	intervals["appendButton"] = window.setInterval(appendButton, 5*1000);
    }
    else {
      console.log("Not going to try and add the button");
      buttonAdded = true
      clearInterval(intervals["appendButton"]);
    }
	})
  window.setTimeout(appendButton, 5*1000);
});
