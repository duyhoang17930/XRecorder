"""Sequence edit distance shared by ASR report tools.

Normalization/tokenization belong to each corpus evaluator: TASK07's NFKC
and script-aware rules intentionally differ from the older NFC benchmark.
"""


def distance(a, b):
    """Unit-cost Levenshtein distance for code points or word sequences."""
    previous = list(range(len(b) + 1))
    for i, left in enumerate(a, 1):
        current = [i]
        for j, right in enumerate(b, 1):
            current.append(min(current[-1] + 1, previous[j] + 1,
                               previous[j - 1] + (left != right)))
        previous = current
    return previous[-1]
