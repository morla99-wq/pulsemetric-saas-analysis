[README.md](https://github.com/user-attachments/files/30102541/README.md)
# PulseMetrics: SaaS Product Analytics Portfolio Project

## Executive Summary

PulseMetrics is a synthetic B2B project-management SaaS product used as the basis for an end-to-end product analytics case study. The project covers 2,200 users and ~132,000 product events across two and a half years (Jan 2024–Jun 2026), spanning the full customer lifecycle: acquisition, activation, engagement, retention/churn, revenue, and support. The analysis was run in PostgreSQL and visualized in Tableau, with the goal of answering the kinds of questions a growth, product, or customer-success team would actually bring to an analyst: where are users coming from, are they getting value, who's churning and why, and where is revenue really being won or lost.

## Key Findings

- **Growth is channel-diversified but Organic Search-led.** Organic Search drives the largest share of signups (~28%), followed by Paid Ads (~20%) and Referral (~14%) — no single channel dominates the funnel.
- **Activation is a bigger drag than "ghost" signups.** Only 4.1% of users never touch the product at all, but just 12.2% of users hit the "activated" bar (creating a project and inviting a teammate within 14 days) — the drop-off happens after the first login, not before it.
- **Churn sits at 28.2% overall**, and it is essentially flat across engagement tiers (24–29%) and between users who filed a support ticket and those who never contacted support. In this dataset, churn does not appear to be explained by product engagement or support contact alone — a signal that other factors (pricing, onboarding quality, competitive pressure) are likely bigger drivers.
- **Cancellation reasons are evenly spread**, with "Poor support experience" and "No longer needed" narrowly the most common, each accounting for roughly 15% of cancellations — no single reason explains the majority of churn.
- **Total active MRR is ~$58,500**, concentrated in a small Enterprise base: Enterprise accounts are only 199 of 1,580 paying users but carry an ARPU of $182.67, vs. $46.24 for Pro and $14.04 for Starter.
- **Social Media and Paid Ads acquire the highest-value customers** by ARPU (~$49 and ~$40 respectively), while Direct and Affiliate bring in the lowest-ARPU users (~$27–29) — a useful input for rethinking channel investment.
- **Support priority doesn't track resolution speed.** Average resolution time is essentially the same regardless of ticket priority (~119–124 hours across Urgent, High, Medium, and Low) — Urgent tickets are not meaningfully resolved faster than Low ones, a real triage/process gap worth flagging.
- **Satisfaction is consistently mid-to-high across ticket categories** (3.7–3.9 out of 5), with Onboarding Help and Feature Request the lowest-rated categories and Account Access the highest.

## Key Questions Answered

1. **Acquisition** — Which channels drive the most signups, and how does the channel mix break down by country, company size, and industry?
2. **Activation** — What share of users go completely inactive ("ghost signups"), and what share reach a meaningful activation milestone in their first two weeks?
3. **Engagement** — What are the most common in-product actions, and how does usage differ across plan tiers?
4. **Retention & Churn** — What is the overall churn rate, how does retention decay by monthly signup cohort, and does churn correlate with engagement level or support contact?
5. **Revenue** — What is total and per-user recurring revenue (MRR/ARPU), how does it break down by plan and channel, and what does the New/Expansion/Contraction/Churned MRR picture look like?
6. **Support** — How quickly are tickets resolved by priority and category, does urgency actually predict resolution speed, and how satisfied are customers with the outcome?

*(Full SQL for all 23 questions and the Tableau build steps are in `PulseMetrics_Analysis_Questions_SQL_Tableau.docx`.)*

## Next Steps & Recommendations

- **Investigate the activation gap before chasing more signups.** With ghost signups at just 4.1% but activation at only 12.2%, the biggest opportunity is the middle of the funnel — users who log in but never create a project and invite a teammate. A cohort-based onboarding email flow or in-app checklist targeting that specific gap would likely move more users than additional top-of-funnel spend.
- **Re-examine the support triage process.** Resolution time not varying by priority suggests tickets aren't being queued or routed by urgency in practice. Worth pulling raw ticket-level data to check whether "Urgent" is a meaningful field at all, or whether it's applied inconsistently at intake.
- **Rebalance channel investment toward ARPU, not just volume.** Organic Search wins on signup count, but Social Media and Paid Ads bring in higher-value customers. Layering in acquisition cost per channel (see Q23 in the analysis doc) would turn this into a proper CAC-vs-ARPU comparison and a clearer case for reallocating budget.
- **Since churn doesn't track engagement or support contact in this dataset, look outside the product.** The next logical step is pulling in data this project doesn't have — pricing changes, competitor activity, sales/CS notes on cancellation calls — to explain the 28.2% churn rate, since usage and support data alone don't predict it here.
- **Treat Enterprise as the account to protect.** Enterprise is 13% of paying users but the highest ARPU by a wide margin ($182.67 vs. $46.24 for Pro). A dedicated retention/expansion motion for this tier (QBRs, dedicated CS coverage) likely has outsized MRR impact relative to its headcount.
- **Extend the analysis with a real predictive model.** The engagement-tier and churn-feature groundwork in Q21–22 is set up to feed a lightweight logistic regression or gradient-boosted churn model in Python — a natural "advanced" add-on if you want to push this project further for the portfolio.
<img width="1400" height="900" alt="PulseMetric_dashboard" src="https://github.com/user-attachments/assets/488d6b6a-00d4-45a4-bfe8-f06390473164" />
