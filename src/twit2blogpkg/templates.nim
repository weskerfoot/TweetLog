import strformat
import karax / [karaxdsl, vdom]

proc renderThread*(author : string,
                   tweets : seq[string]): string =

  let title = fmt"Thread by {author}"
  let vnode = buildHtml(tdiv(class = "mt-3")):
    h4: text title
    ul:
      li: a(href="/"): text "Main Page"
      li: a(href=fmt"/author/{author}/threads"): text (fmt"See all of {author}'s threads")
    ul:
      for tweet in tweets:
        li: text tweet
  result = $vnode

proc checkBack*() : string =
  let vnode = buildHtml(tdiv(class = "mt-3")):
    h4: text "Check back later please"
  result = $vnode

proc listAuthors*(authors : seq[string]) : string =
  let title = "Authors"
  let vnode = buildHtml(tdiv(class = "mt-3")):
    h4: text title
    ul:
      for author in authors:
        li: a(href = fmt"/author/{author}/threads"): text author
  result = $vnode

proc listThreads*(author : string,
                  threads : seq[string]) : string =
  let title = fmt"Threads for {author}"
  let vnode = buildHtml(tdiv(class = "mt-3")):
    a(href="/"): text "Main Page"
    h4: text title
    ul:
      for thread in threads:
        li: a(href = fmt"/thread/{author}/status/{thread}"): text thread
  result = $vnode
