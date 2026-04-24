# Wiki Deliverable Checklist

Use this checklist to ensure you have all required elements for your Customer Discovery assignment.

## ✅ Required Deliverables

### 1. Target Audience Rationale
- [ ] Who is the desperate user?
- [ ] Why this specific audience?
- [ ] Problem they're trying to solve

**Data source:** Your team's research + observations during testing

---

### 2. Expertise Building
- [ ] How did you learn about your target audience?
- [ ] What research did you conduct?
- [ ] Who did you talk to?

**Data source:** Your team's process documentation

---

### 3. User Interactions
- [ ] **Total number of real-time interactions**
  - Count: _____
  - Breakdown by type/location if relevant

**Data source:** Your testing records + analytics
- Run `python3 analyze.py` and check "Total sessions" from summary

Example table:
| Testing Session | User Count | Location | Date |
|----------------|------------|----------|------|
| Session 1      | 3          | Stanford | 4/23 |
| Session 2      | 2          | Off-campus | 4/23 |
| **Total**      | **5**      | -        | -    |

---

### 4. Prototype Testing & Data Collection

#### A. Prototype Type
- [ ] **Functional prototype** (your Eta app) ✅
- [ ] Instrumented to collect usage data ✅

#### B. Data Collected

**Quantitative (Passive):**

Run these commands and include outputs:
```bash
python3 analyze.py > wiki_stats.txt
python3 visualize.py  # Generates PNG charts
```

**Permission Metrics:**
| Permission Type | Requested | Granted | Denied | Grant Rate | Avg Time (s) |
|----------------|-----------|---------|--------|------------|--------------|
| Calendar       |           |         |        |            |              |
| Contacts       |           |         |        |            |              |

**Onboarding Metrics:**
| Metric             | Value |
|--------------------|-------|
| Avg Duration (s)   |       |
| Completion Rate    |       |

**Connection Metrics:**
| Metric                   | Total | Avg per User |
|--------------------------|-------|--------------|
| Connections Added        |       |              |
| % of Contacts Added      |       |              |
| Connections Edited       |       |              |

**Suggestion Metrics:**
| Metric                | Count | Rate |
|-----------------------|-------|------|
| Suggestions Generated |       |      |
| Viewed                |       |      |
| Tapped                |       | _%   |

**Invitation Metrics:**
| Stage            | Count | Conversion |
|------------------|-------|------------|
| Initiated        |       | 100%       |
| Completed        |       | _%         |
| Yes Response     |       | _%         |

**Screen Time:**
| Screen              | Total Time (s) | Avg Time (s) | Views |
|---------------------|----------------|--------------|-------|
| ConnectionsView     |                |              |       |
| SuggestionView      |                |              |       |
| AddConnectionSheet  |                |              |       |

**Qualitative (Active):**
- [ ] User feedback during testing
- [ ] Post-test interviews/surveys
- [ ] Observed pain points
- [ ] Feature requests

---

### 5. Tabular Display of Data

**Include these tables in your wiki:**

1. ✅ Permission funnel (see template above)
2. ✅ Onboarding stats (see template above)
3. ✅ Connection behavior (see template above)
4. ✅ Suggestion engagement (see template above)
5. ✅ Invitation conversion (if feature completed)
6. ✅ Screen time breakdown (see template above)
7. ✅ User interaction count summary

**Visual Charts (from `visualize.py`):**
- [ ] `permission_funnel.png`
- [ ] `invitation_funnel.png`
- [ ] `screen_time.png`
- [ ] `activity_breakdown.png`
- [ ] `time_of_day.png`

---

### 6. Updated PRD

Based on your learnings:
- [ ] What assumptions were validated?
- [ ] What assumptions were invalidated?
- [ ] What new requirements emerged?
- [ ] What features should be prioritized/deprioritized?

**Data-driven insights:**
- If permission grant rate was low → add explanation screen
- If suggestions were rarely tapped → rethink suggestion algorithm
- If users added few connections → simplify onboarding
- If certain screens had long dwell times → check for confusion

---

## 📊 How to Fill In Your Data

### Step 1: Export from App
```
Triple-tap bottom-right corner → Export Analytics Data → AirDrop to Mac
```

### Step 2: Analyze
```bash
cd Analytics
python3 analyze.py > stats_output.txt
python3 visualize.py
```

### Step 3: Extract Stats

Open `stats_output.txt` and `Data/eta_summary_YYYY-MM-DD_HH-MM-SS.json`

Copy values into tables above.

### Step 4: Explore Details (Optional)
```bash
python3 query.py

eta> sessions          # List all sessions
eta> user Session_001  # Drill into specific user
eta> permissions       # All permission events
eta> invitations       # All invitation events
```

---

## 💡 Tips for Strong Deliverable

### Criterion 1: Volume of Interactions
- **Weighted by difficulty of reaching audience**
- If your target is "busy Stanford students" → 5 users is good
- If your target is "general consumers" → aim for 10+
- **Document your recruitment process**

### Criterion 2: Quality of Interactions
- ✅ **Best:** Functional prototype with passive data collection (YOU HAVE THIS!)
- ⭐ **Better:** Static prototypes with structured observation
- ⚠️ **Acceptable:** Surveys and verbal discussion
- ❌ **Not acceptable:** No user interaction

**You're set up for full marks on Criterion 2!**

### Making Your Data Shine

**Tell a story with your data:**
1. "We tested with X users over Y hours"
2. "Users granted calendar permission in an average of 4.2s"
3. "66% of viewed suggestions were tapped → high engagement"
4. "Users only added 3% of available contacts → suggests selectivity"
5. "Based on this data, we're updating our PRD to..."

**Show before/after:**
- "We assumed users would add 10+ friends"
- "Data showed average of 4.6 → updated PRD to optimize for smaller circles"

---

## 🚀 Final Check

Before submitting:
- [ ] All tables filled with real data
- [ ] Charts embedded in wiki
- [ ] Story/narrative connects data to insights
- [ ] PRD updates justified by data
- [ ] Raw data referenced (in repo or appendix)
- [ ] Tested with real target audience members
- [ ] Volume and quality criteria addressed

---

**Need More Users?**

If you need more data points:
1. Export current data (don't lose it!)
2. Continue testing with more users
3. Export again (files won't overwrite)
4. Aggregate data across all exports

---

**Questions?**
- See `ANALYTICS_IMPLEMENTATION.md` for technical details
- See `Analytics/README.md` for analysis tool usage
- See `TESTING_QUICK_REFERENCE.md` for testing workflow
