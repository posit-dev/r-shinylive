## Comments

#### 2026-04-06

CRAN package shinylive

This violates the CRAN policy by leaving ca 737MB in ~/.cache/shinylive,
a location that is not even allowed to be used.

(~/Library/Caches/shinylive on macOS)

It will be removed from CRAN. Then we will have to go round sweeping up
after you on several machines ....

- Brian D. Ripley


#### 2026-04-06

Sorry for the required cleanup. I had a test slip through the cracks.

Changes made to address the cache folder being created during testing (https://github.com/posit-dev/r-shinylive/pull/186):
* Added a runtime guard in `assets_cache_dir()` to error during CRAN testing, preventing any future cache directory creation on CRAN.
* Tests that interact with the shinylive assets cache directory are now skipped on CRAN.

Please let me know if I can provide any more information.

Thank you for your time,
Barret



## R CMD check results

0 errors | 0 warnings | 1 note

```
─  checking CRAN incoming feasibility ... [3s/17s] NOTE (16.7s)
   Maintainer: ‘Barret Schloerke <barret@posit.co>’

   New submission

   Package was archived on CRAN

   Version contains large components (0.4.0.9000)

   CRAN repository db overrides:
     X-CRAN-Comment: Archived on 2026-04-06 for policy violation.

     Use of ~/.cache/shinylive, leaving 700+MB behind.
```



## Reverse dependencies

No reverse dependencies.
