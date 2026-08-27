# World 8 SSRN — Verified Related Work v0.1

Verification date: 2026-08-27
Status: VERIFIED BIBLIOGRAPHY / MANUSCRIPT INPUT

This bibliography contains only references whose bibliographic metadata and persistent identifier / authoritative publication page were independently checked before manuscript use. Relevance notes are editorial summaries for World 8 and are not claims made by the cited authors.

## 1. Proper probabilistic scoring

**Brier, G. W. (1950).** Verification of forecasts expressed in terms of probability. *Monthly Weather Review, 78*(1), 1–3. DOI: `10.1175/1520-0493(1950)078<0001:VOFEIT>2.0.CO;2`.

Authoritative page: https://journals.ametsoc.org/doi/10.1175/1520-0493%281950%29078%3C0001%3AVOFEIT%3E2.0.CO%3B2

World 8 relevance: basis for the Brier score used as the primary proper scoring rule in the event-probability replay.

**Gneiting, T., & Raftery, A. E. (2007).** Strictly proper scoring rules, prediction, and estimation. *Journal of the American Statistical Association, 102*(477), 359–378. DOI: `10.1198/016214506000001437`.

DOI: https://doi.org/10.1198/016214506000001437

World 8 relevance: theoretical foundation for using proper scoring rules to evaluate probabilistic forecasts without conflating the forecast with a downstream decision.

## 2. Probability calibration

**Niculescu-Mizil, A., & Caruana, R. (2005).** Predicting good probabilities with supervised learning. In *Proceedings of the 22nd International Conference on Machine Learning (ICML '05)*, 625–632. DOI: `10.1145/1102351.1102430`.

DOI: https://doi.org/10.1145/1102351.1102430

World 8 relevance: classic empirical comparison of probability-estimation/calibration behavior and post-processing methods; relevant to the Platt-style calibration layer in the replay.

**Guo, C., Pleiss, G., Sun, Y., & Weinberger, K. Q. (2017).** On calibration of modern neural networks. *Proceedings of the 34th International Conference on Machine Learning*, PMLR 70, 1321–1330.

Authoritative page: https://proceedings.mlr.press/v70/guo17a.html

World 8 relevance: modern calibration evidence and methodology; supports treating calibration as an explicit, separately evaluated layer rather than assuming raw model confidence is probabilistically meaningful.

## 3. Forecast combination and ensembles

**Clemen, R. T. (1989).** Combining forecasts: A review and annotated bibliography. *International Journal of Forecasting, 5*(4), 559–583. DOI: `10.1016/0169-2070(89)90012-5`.

Authoritative page: https://www.sciencedirect.com/science/article/pii/0169207089900125

World 8 relevance: establishes the long-standing forecast-combination literature and the importance of comparing simple aggregation with more elaborate weighting rules.

**Wang, X., Hyndman, R. J., Li, F., & Kang, Y. (2023).** Forecast combinations: An over 50-year review. *International Journal of Forecasting, 39*(4), 1518–1547. DOI: `10.1016/j.ijforecast.2022.11.005`.

Authoritative pages:
- https://www.sciencedirect.com/science/article/pii/S0169207022001480
- https://research.monash.edu/en/publications/forecast-combinations-an-over-50-year-review/

World 8 relevance: contemporary review covering simple and sophisticated combination methods, time-varying weights, correlations, and probabilistic forecast combinations. It is directly relevant to the majority-vote, equal-weight, calibrated-weighted, and correlation-aware variants evaluated here.

## 4. Comparative forecast evaluation

**Diebold, F. X., & Mariano, R. S. (1995).** Comparing predictive accuracy. *Journal of Business & Economic Statistics, 13*(3), 253–263. DOI: `10.1080/07350015.1995.10524599`.

Authoritative page: https://www.tandfonline.com/doi/abs/10.1080/07350015.1995.10524599

World 8 relevance: foundational work on comparison of competing forecast loss sequences with serial dependence. The current World 8 v0.1 study uses paired moving-block bootstrap rather than claiming a Diebold–Mariano test, but this reference anchors the broader literature on comparative predictive accuracy and dependent forecast errors.

## Methodological positioning for the manuscript

The World 8 empirical claim should remain narrow:

1. The architecture separates **Forecast**, **Decision**, and **Order** so probabilistic forecasts can be scored by proper scoring rules independently of downstream utility/execution.
2. Calibration and forecast combination are established research areas; World 8 does not claim invention of either.
3. The empirical contribution of this study is the evidence-bounded evaluation protocol and its application to immutable Forecast Contracts under deterministic replay, including negative ablation results.
4. Majority vote is used as a deliberately simple baseline, not as a straw-man claim about the entire forecast-combination literature.
5. The paired moving-block bootstrap is used to retain time dependence in loss differences; no asymptotic DM significance claim should be written unless a correctly specified DM analysis is separately implemented and validated.

## Evidence boundary

These references do not support claims of trading profitability, production readiness, autonomous intelligence, or universal superiority of World 8. They support the evaluation concepts used in the manuscript: proper scoring, calibration, forecast combination, and comparative predictive evaluation.
