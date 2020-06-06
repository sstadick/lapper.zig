# lapper.zig

Yet another clone of [`nim-lapper`](https://github.com/brentp/nim-lapper), but this time in zig!

## Usage

See `example.zig` for how this is used to calculate coverage

## Performance

On the [biofast](https://github.com/lh3/biofast) dataset, this alogorithm is competitive, but shows some weakness depending on the how nested the intervals are.

Generally speaking, the `seek` method should be much faster when you know your queries will be in order.

### Results running on the biofast dataset
```bash
## rna - anno (g2r)
$ /usr/bin/time ./zig-cache/bin/bedcov-zig ../biofast/biofast-data-v1/ex-rna.bed ../biofast/biofast-data-v1/ex-anno.bed >  rna_anno_out.bed
       10.71 real        10.48 user         0.22 sys
$ /usr/bin/time ../biofast/bedcov/bedcov_c1_cgr ../biofast/biofast-data-v1/ex-rna.bed ../biofast/biofast-data-v1/ex-anno.bed >  /tmp/rna_anno_out.bed
        3.54 real         3.44 user         0.10 sys
$ md5sum rna_anno_out.bed
4340dbc9be79d7146b76a7872dfcd574  rna_anno_out.bed
$ md5sum ./rna_anno_out.bed
4340dbc9be79d7146b76a7872dfcd574  ./rna_anno_out.bed

## anno - rna (r2g)
$ /usr/bin/time ./zig-cache/bin/bedcov-zig ../biofast/biofast-data-v1/ex-anno.bed ../biofast/biofast-data-v1/ex-rna.bed >  anno_rna_out.bed
        6.98 real         6.10 user         0.86 sys
$ /usr/bin/time ../biofast/bedcov/bedcov_c1_cgr ../biofast/biofast-data-v1/ex-anno.bed ../biofast/biofast-data-v1/ex-rna.bed >  /tmp/anno_rna_out.bed
        7.38 real         6.94 user         0.41 sys
$ md5sum ./anno_rna_out.bed
282782b1835fc2b34ab97306dfd0440d  ./anno_rna_out.bed
$ md5sum /tmp/anno_rna_cout.bed
282782b1835fc2b34ab97306dfd0440d  /tmp/anno_rna_cout.bed
```

## Notes

- This uses the zig builtin sort method. Radix sort should be faster.
- This algorithm has a bad worst case when there are massive intervals that envelop many smaller intervals.
- I am new to zig, there are surely little things that could be done better.