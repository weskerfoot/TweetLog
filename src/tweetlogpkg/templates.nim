import strformat
import karax / [karaxdsl, vdom]

proc layout(inner : VNode, title : string) : string =
  let vnode = buildHtml(html):
    head:
      meta(charset="utf-8")
      link(href="https://unpkg.com/tailwindcss@^1.0/dist/tailwind.min.css", rel="stylesheet")
    body:
      h1(class="text-center"): text title
      tdiv(class="text-center appearance-none"):
        inner
  "<!DOCTYPE html>\n" & $vnode

proc tweetThread*(author : string,
                  tweets : seq[string]): string =

  let title = fmt"Thread by {author}"
  let vnode = buildHtml(tdiv(class="")):
    h4: text title
    ul:
      li: a(href="/"): text "Main Page"
      li: a(href=fmt"/author/{author}/threads"): text (fmt"See all of {author}'s threads")
    ul(class="m-auto max-w-md list-decimal text-left"):
      for tweet in tweets:
        li: text tweet
  result = $vnode.layout("Threads")

proc checkBack*() : string =
  let vnode = buildHtml(tdiv):
    h4: text "Check back later please"
  result = $vnode.layout("Check back")

proc listThreads*(author : string,
                  threads : seq[string]) : string =
  let title = fmt"Threads for {author}"
  let vnode = buildHtml(tdiv):
    a(href="/"): text "Main Page"
    h4: text title
    ul:
      for thread in threads:
        li: a(href=fmt"/thread/{author}/status/{thread}"): text thread
  result = $vnode.layout("Threads")

# Main page

proc listAuthors*(authors : seq[string]) : VNode =
  let title = "Authors"
  let vnode = buildHtml(tdiv):
    h1(class="uppercase text-center"): text title
    ul(class="text-center"):
      for author in authors:
        li:
          a(href = fmt"/author/{author}/threads"):
            text author
  result = vnode

proc submitThread() : VNode =
  let vnode = buildHtml(tdiv):
    form(action = "/thread", `method`="POST", class="appearance-none"):
      tdiv(class="text-center"):
        label(`for`="tweetUrl"):
          text "Tweet URL"
        input(class="bg-teal-100", `type`="text", name="tweetURL", id="tweeturl", required="true")
  result = vnode

proc mainPage*(authors : seq[string]) : string =
  let vnode = buildHtml(tdiv(class="grid grid-cols-2 gap-4")):
    tdiv:
      listAuthors(authors)
    tdiv:
      submitThread()
  result = $vnode.layout("Tweetlog")
