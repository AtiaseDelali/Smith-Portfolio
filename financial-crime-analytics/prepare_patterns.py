"""Turn the IBM AML patterns text file into a CSV.

The patterns file is a text report, not a table: each laundering scheme is
wrapped in a 'BEGIN LAUNDERING ATTEMPT - <PATTERN>' line and an
'END LAUNDERING ATTEMPT' line, with one transaction per line in between.
This script adds a scheme ID, the pattern name and the pattern detail to
every transaction line and writes a normal CSV with a header row.
"""
import csv

COLUMNS = ['attempt_id', 'pattern', 'pattern_detail', 'timestamp',
           'from_bank', 'from_account', 'to_bank', 'to_account',
           'amount_received', 'receiving_currency', 'amount_paid',
           'payment_currency', 'payment_format', 'is_laundering']

attempt_id, pattern, detail = 0, None, None
with open('HI-Large_Patterns.txt', encoding='utf-8') as src, \
     open('laundering_patterns.csv', 'w', newline='', encoding='utf-8') as out:
    writer = csv.writer(out)
    writer.writerow(COLUMNS)
    for line in src:
        line = line.strip()
        if not line or line.startswith('END LAUNDERING ATTEMPT'):
            continue
        if line.startswith('BEGIN LAUNDERING ATTEMPT'):
            attempt_id += 1
            name = line.split(' - ', 1)[1]          # e.g. 'CYCLE:  Max 12 hops'
            pattern, _, detail = name.partition(':')
            pattern, detail = pattern.strip(), detail.strip()
            continue
        writer.writerow([attempt_id, pattern, detail] + line.split(','))
print('schemes:', attempt_id)
