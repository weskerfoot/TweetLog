import strformat
import karax / [karaxdsl, vdom]

proc tweetThread*(author : string,
                  tweets : seq[string]): string =

  let title = fmt"Thread by {author}"
  let vnode = buildHtml(tdiv):
    h4: text title
    ul:
      li: a(href="/"): text "Main Page"
      li: a(href=fmt"/author/{author}/threads"): text (fmt"See all of {author}'s threads")
    ul:
      for tweet in tweets:
        li: text tweet
  result = $vnode

proc checkBack*() : string =
  let vnode = buildHtml(tdiv):
    h4: text "Check back later please"
  result = $vnode

proc listThreads*(author : string,
                  threads : seq[string]) : string =
  let title = fmt"Threads for {author}"
  let vnode = buildHtml(tdiv):
    a(href="/"): text "Main Page"
    h4: text title
    ul:
      for thread in threads:
        li: a(href = fmt"/thread/{author}/status/{thread}"): text thread
  result = $vnode

# Main page

proc listAuthors*(authors : seq[string]) : VNode =
  let title = "Authors"
  let vnode = buildHtml(tdiv):
    h4: text title
    ul:
      for author in authors:
        li: a(href = fmt"/author/{author}/threads"): text author
  result = vnode

proc submitThread() : VNode =
  let vnode = buildHtml(tdiv):
    form(action = "/thread", `method`="POST", class="submit-thread"):
      tdiv:
        label(`for`="tweetUrl"):
          text "Tweet URL"
        input(`type`="text", name="tweetURL", id="tweeturl", required="true")
  result = vnode

proc mainPage*(authors : seq[string]) : string =
  let vnode = buildHtml(tdiv):
    listAuthors(authors)
    submitThread()
  result = $vnode
