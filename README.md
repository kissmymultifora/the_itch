# the_itch
I want to take something very simple and run it through AI dev tool - TBD with a prompt to improve its maintainability. I know that it’s absurd ask, but I work in software, so absurd requests are not that uncommon. And luckily for me LLMs don’t really have the power of saying “No”.

One-liner candidate is:
```
 awk -F'|' 'NR == FNR { $1 = ""; $2 = ""; seen[$0]++ } NR != FNR { orig = $0; $1 = ""; $2 = ""; if (!seen[$0]) print orig }' first.txt second.txt
```

Wordle candidate is:
[Wordle in less than 50 lines of Bash](https://gist.github.com/huytd/6a1a6a7b34a0d0abcac00b47e3d01513)