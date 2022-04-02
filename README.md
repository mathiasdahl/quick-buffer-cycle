# quick-buffer-cycle

Yet another one-key buffer switcher for Emacs

## Background

For a long time (*) I have had the F1 key bound to a command that
takes me to the previous buffer. It has been a very simple command
and it has served me well. I use this in every editing session more
or less.

* I think I first got the idea here: https://www.emacswiki.org/emacs/DedicatedKeys

Certain days I am repeating the same buffer switching pattern over
and over again. I switch to buffer A, then B, then C, and then A
again (or whatever). Those days, my convenient F1 binding does not
work for me and I have to use some sort of classic "buffer
selector" (sometimes I use the standard one in Emacs, but often I
use Anything (precursor to Helm)), which of course works but is
slower/boring.

This hack is my attempt to solve it. The idea is that, in a given
scenario, I will quickly learn that I first press F1 once, to
switch to buffer A and do some work there. Then I press the key
twice to switch to buffer C and work there, then press twice again
to switch to buffer B, and so on. In my use cases, probably I will
seldom press the key more than twice, but we'll see about that.

Before I wrote this hack I made an attempt to find if there were a
package like this already, but could not find one. Turns out I was
wrong (perhaps I did not want to find it, it is fun to reinvent the
wheel afterall...), but I learned this after developing this
one... At any rate, now it's done and I will try to use it to see
if I like it. Preliminary results shows that I will...

## About the approach using a timer

At first I tried an approach where I measured the time between each
call to the "switch" command. Long story short I could not get it
work the way I wanted to (it now seems others have succeeded and at
least one of those solution seems to be quite complex, which is
perhaps why I did not succeed) and got the idea that a timer would
be the solution - simply wait with switching buffers until the user
has stopped "cycling".

The solution is very simple, but it has one major drawback,
especially for the impatient: you can never switch to a buffer more
quickly than what the timer delay is set to (0.4 seconds by
default). You can tweak the timer value to whatever suits you. If
you have a fast computer and if you are a fast typist, you should
certainly try with 0.3 or even 0.2. If you can live with this
delay, this simple hack will probably work well for you.

## Usage:

Bind `quick-buffer-cycle' to a convenient key. I prefer the F1 key:

(global-set-key [f1] 'quick-buffer-cycle)

Now, the most common scenario (for me) is that I want to switch to
the previous buffer. To do that, press the key once, and wait (the
default time to wait is 0.4 seconds). The previous buffer will be
selected.

If you know "where" in the buffer stack/list the buffer is that you
want to go to, quickly press the key as many times is needed to
select that buffer (let's say two times, if you know the buffer you
want is the one previous to the previous one). Here, "quickly"
means to press the key with a maximum delay of
`quick-buffer-cycle-timeout' (default 0.4 seconds).

To make it easier to select the correct buffer, when you pressed
the key the wrong number of times, there is a hint in the echo area
that shows how many key presses are needed to get to a certain
buffer after a buffer have been switched to. By default, the number
of buffers to show in the hint is 4 but this can be customized by
setting `quick-buffer-cycle-hint-limit' to the number of buffers to
be shown.

