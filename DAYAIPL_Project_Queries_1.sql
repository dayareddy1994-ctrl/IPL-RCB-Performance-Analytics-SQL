USE ipl;

SELECT 'Player' AS Table_Name, COUNT(*) AS Row_Count FROM Player
UNION ALL SELECT 'Ball_by_Ball', COUNT(*) FROM Ball_by_Ball
UNION ALL SELECT 'Matches', COUNT(*) FROM Matches
UNION ALL SELECT 'Player_Match', COUNT(*) FROM Player_Match
UNION ALL SELECT 'Wicket_Taken', COUNT(*) FROM Wicket_Taken
UNION ALL SELECT 'Extra_Runs', COUNT(*) FROM Extra_Runs
UNION ALL SELECT 'Season', COUNT(*) FROM Season
UNION ALL SELECT 'Team', COUNT(*) FROM Team
UNION ALL SELECT 'Venue', COUNT(*) FROM Venue;

USE ipl;

SELECT 'Player' AS Table_Name, COUNT(*) AS Row_Count FROM Player
UNION ALL SELECT 'Ball_by_Ball', COUNT(*) FROM Ball_by_Ball
UNION ALL SELECT 'Matches', COUNT(*) FROM Matches
UNION ALL SELECT 'Player_Match', COUNT(*) FROM Player_Match
UNION ALL SELECT 'Wicket_Taken', COUNT(*) FROM Wicket_Taken
UNION ALL SELECT 'Extra_Runs', COUNT(*) FROM Extra_Runs
UNION ALL SELECT 'Season', COUNT(*) FROM Season
UNION ALL SELECT 'Team', COUNT(*) FROM Team
UNION ALL SELECT 'Venue', COUNT(*) FROM Venue;

USE ipl;
-- Q1: List the different data types of columns in table 'ball_by_ball' using INFORMATION_SCHEMA.COLUMNS
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_KEY
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ipl'
  AND TABLE_NAME = 'ball_by_ball'
ORDER BY ORDINAL_POSITION;

USE ipl;
/*
Q2: What is the total number of runs scored by RCB
in the 1st season?
Bonus: Also include the extra runs using the Extra_Runs table.
*/-- Basic version
SELECT
    SUM(b.Runs_Scored) + COALESCE(SUM(e.Extra_Runs),0) AS total_runs_including_extras
FROM ball_by_ball b
JOIN matches m
    ON b.Match_Id = m.Match_Id
LEFT JOIN extra_runs e
    ON b.Match_Id = e.Match_Id
   AND b.Over_Id = e.Over_Id
   AND b.Ball_Id = e.Ball_Id
   AND b.Innings_No = e.Innings_No
WHERE b.Team_Batting = 2
AND m.Season_Id = (
    SELECT MIN(Season_Id)
    FROM matches
);

/*
Q3: How many players were more than 25 years old
during the 2014 season?
*/

SELECT COUNT(DISTINCT pm.Player_Id) AS players_above_25
FROM player_match pm
JOIN matches m
    ON pm.Match_Id = m.Match_Id
JOIN player p
    ON pm.Player_Id = p.Player_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE s.Season_Year = 2014
AND TIMESTAMPDIFF(YEAR, p.DOB, '2014-01-01') > 25;

/*
Q4: How many matches did RCB win
during the 2013 season?
*/

SELECT COUNT(*) AS matches_won
FROM matches m
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE s.Season_Year = 2013
AND m.Match_Winner = (
    SELECT Team_Id
    FROM team
    WHERE Team_Name = 'Royal Challengers Bangalore'
);    

/*
Q5: List the top 10 players according to
their strike rate in the last four seasons.
*/

SELECT
    p.Player_Name,
    ROUND((SUM(b.Runs_Scored) * 100.0) / COUNT(*), 2) AS Strike_Rate
FROM ball_by_ball b
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN player p ON b.Striker = p.Player_Id
WHERE m.Season_Id IN (
    SELECT Season_Id
    FROM (
        SELECT Season_Id
        FROM season
        ORDER BY Season_Year DESC
        LIMIT 4
    ) x
)
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(*) > 50
ORDER BY Strike_Rate DESC LIMIT 10;

/*
Q6: What are the average runs scored
by each batsman across all seasons?
*/

SELECT
    p.Player_Name,
    ROUND(AVG(b.Runs_Scored), 2) AS Average_Runs
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Id, p.Player_Name
ORDER BY Average_Runs DESC;

/*
Q7: What are the average wickets taken
by each bowler across all seasons?
*/

SELECT
    p.Player_Name,
    ROUND(COUNT(w.Player_Out) / COUNT(DISTINCT m.Season_Id), 2) AS Avg_Wickets_Per_Season
FROM wicket_taken w
JOIN ball_by_ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN player p
    ON b.Bowler = p.Player_Id
JOIN matches m
    ON b.Match_Id = m.Match_Id
GROUP BY p.Player_Id, p.Player_Name
ORDER BY Avg_Wickets_Per_Season DESC;

/*
Q8: List all players whose average runs
are greater than the overall average
and whose wickets are greater than
the overall average.
*/

SELECT
    p.Player_Name,
    bat.avg_runs,
    bowl.total_wickets
FROM player p
JOIN
(
    SELECT
        Striker AS Player_Id,
        AVG(Runs_Scored) AS avg_runs
    FROM ball_by_ball
    GROUP BY Striker
) bat
ON p.Player_Id = bat.Player_Id
JOIN
(
    SELECT
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS total_wickets
    FROM wicket_taken w
    JOIN ball_by_ball b
      ON w.Match_Id = b.Match_Id
     AND w.Over_Id = b.Over_Id
     AND w.Ball_Id = b.Ball_Id
     AND w.Innings_No = b.Innings_No
    GROUP BY b.Bowler
) bowl
ON p.Player_Id = bowl.Player_Id
WHERE bat.avg_runs >
(
    SELECT AVG(Runs_Scored)
    FROM ball_by_ball
)
AND bowl.total_wickets >
(
    SELECT AVG(wicket_count)
    FROM
    (
        SELECT COUNT(w.Player_Out) AS wicket_count
        FROM wicket_taken w
        JOIN ball_by_ball b
          ON w.Match_Id = b.Match_Id
         AND w.Over_Id = b.Over_Id
         AND w.Ball_Id = b.Ball_Id
         AND w.Innings_No = b.Innings_No
        GROUP BY b.Bowler
    ) x
)
ORDER BY bat.avg_runs DESC;

/*
Q9: Create an RCB_Record table showing
the wins and losses of RCB
at each venue.
*/

DROP TABLE IF EXISTS rcb_record;

CREATE TABLE rcb_record AS
SELECT
    v.Venue_Name,
    SUM(CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END) AS Wins,
    SUM(
        CASE
            WHEN (m.Team_1 = 2 OR m.Team_2 = 2)
             AND m.Match_Winner <> 2
            THEN 1
            ELSE 0
        END
    ) AS Losses
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
WHERE m.Team_1 = 2
   OR m.Team_2 = 2
GROUP BY v.Venue_Id, v.Venue_Name;

SELECT *
FROM rcb_record
ORDER BY Wins DESC;

/*
Q10: What is the impact of
bowling style on wickets taken?
*/

SELECT
    bs.Bowling_skill AS Bowling_Style,
    COUNT(w.Player_Out) AS Total_Wickets
FROM wicket_taken w
JOIN ball_by_ball b
    ON w.Match_Id = b.Match_Id
   AND w.Over_Id = b.Over_Id
   AND w.Ball_Id = b.Ball_Id
   AND w.Innings_No = b.Innings_No
JOIN player p
    ON b.Bowler = p.Player_Id
JOIN bowling_style bs
    ON p.Bowling_skill = bs.Bowling_Id
GROUP BY bs.Bowling_skill
ORDER BY Total_Wickets DESC;

/*
Q11: Compare each team's performance
with the previous season based on
total runs scored and wickets taken.
*/



SELECT
    cur.Team_Name,
    cur.Season_Year,
    cur.total_runs,
    cur.total_wickets,
    CASE
        WHEN prev.total_runs IS NULL THEN 'First Season'
        WHEN cur.total_runs > prev.total_runs
         AND cur.total_wickets > prev.total_wickets
            THEN 'Better'
        WHEN cur.total_runs < prev.total_runs
         AND cur.total_wickets < prev.total_wickets
            THEN 'Worse'
        ELSE 'Mixed'
    END AS Performance_Status
FROM
(
    SELECT
        t.Team_Id,
        t.Team_Name,
        s.Season_Year,
        SUM(b.Runs_Scored) AS total_runs,
        COUNT(w.Player_Out) AS total_wickets
    FROM ball_by_ball b
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    JOIN season s
        ON m.Season_Id = s.Season_Id
    JOIN team t
        ON b.Team_Batting = t.Team_Id
    LEFT JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    GROUP BY t.Team_Id, t.Team_Name, s.Season_Year
) cur
LEFT JOIN
(
    SELECT
        t.Team_Id,
        t.Team_Name,
        s.Season_Year,
        SUM(b.Runs_Scored) AS total_runs,
        COUNT(w.Player_Out) AS total_wickets
    FROM ball_by_ball b
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    JOIN season s
        ON m.Season_Id = s.Season_Id
    JOIN team t
        ON b.Team_Batting = t.Team_Id
    LEFT JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
       AND b.Over_Id = w.Over_Id
       AND b.Ball_Id = w.Ball_Id
       AND b.Innings_No = w.Innings_No
    GROUP BY t.Team_Id, t.Team_Name, s.Season_Year
) prev
    ON cur.Team_Id = prev.Team_Id
   AND cur.Season_Year = prev.Season_Year + 1
ORDER BY cur.Team_Name, cur.Season_Year;

/*
Q12: Derive additional KPIs
for team strategy.
*/

SELECT
    t.Team_Name,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,
    ROUND(
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 100.0 /
        COUNT(*), 2
    ) AS Win_Percentage
FROM team t
JOIN matches m
    ON t.Team_Id IN (m.Team_1, m.Team_2)
GROUP BY t.Team_Id, t.Team_Name
ORDER BY Win_Percentage DESC;

-- AVERAGE TEAM SCORE
SELECT
    t.Team_Name,
    ROUND(AVG(team_runs),2) AS Avg_Team_Score
FROM
(
    SELECT
        Match_Id,
        Team_Batting,
        SUM(Runs_Scored) AS team_runs
    FROM ball_by_ball
    GROUP BY Match_Id, Team_Batting
) x
JOIN team t
    ON x.Team_Batting = t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Team_Score DESC;

-- AVERAGE WICKETS TAKEN PER MATCH
SELECT
    t.Team_Name,
    ROUND(COUNT(w.Player_Out) /
          COUNT(DISTINCT b.Match_Id), 2) AS Avg_Wickets_Per_Match
FROM wicket_taken w
JOIN ball_by_ball b
    ON w.Match_Id=b.Match_Id
   AND w.Over_Id=b.Over_Id
   AND w.Ball_Id=b.Ball_Id
   AND w.Innings_No=b.Innings_No
JOIN team t
    ON b.Team_Bowling=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Wickets_Per_Match DESC;

-- BOUNDARY DEPENDENCY
SELECT
    t.Team_Name,
    SUM(CASE WHEN b.Runs_Scored IN (4,6) THEN b.Runs_Scored ELSE 0 END) AS Boundary_Runs,
    SUM(b.Runs_Scored) AS Total_Runs,
    ROUND(
        SUM(CASE WHEN b.Runs_Scored IN (4,6) THEN b.Runs_Scored ELSE 0 END)
        *100.0 / SUM(b.Runs_Scored),2
    ) AS Boundary_Percentage
FROM ball_by_ball b
JOIN team t
    ON b.Team_Batting=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Boundary_Percentage DESC;

-- TOSS IMPACT ANALYSIS
SELECT
    t.Team_Name,
    COUNT(*) AS Tosses_Won,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS Toss_And_Match_Won
FROM matches m
JOIN team t
    ON m.Toss_Winner=t.Team_Id
GROUP BY t.Team_Name;

-- HOME VENUE ADVANTAGE
SELECT
    v.Venue_Name,
    COUNT(*) AS Matches,
    SUM(CASE WHEN Match_Winner = 2 THEN 1 ELSE 0 END) AS RCB_Wins
FROM matches m
JOIN venue v
    ON m.Venue_Id=v.Venue_Id
WHERE Team_1=2 OR Team_2=2
GROUP BY v.Venue_Name;

-- Death Overs Performance (16–20 Overs)
SELECT
    t.Team_Name,
    ROUND(AVG(death_runs),2) AS Avg_Death_Overs_Runs
FROM
(
    SELECT
        Match_Id,
        Team_Batting,
        SUM(Runs_Scored) AS death_runs
    FROM ball_by_ball
    WHERE Over_Id BETWEEN 16 AND 20
    GROUP BY Match_Id, Team_Batting
) x
JOIN team t
    ON x.Team_Batting=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Death_Overs_Runs DESC;

-- Powerplay Performance (Overs 1–6)
SELECT
    t.Team_Name,
    ROUND(AVG(pp_runs),2) AS Avg_Powerplay_Runs
FROM
(
    SELECT
        Match_Id,
        Team_Batting,
        SUM(Runs_Scored) AS pp_runs
    FROM ball_by_ball
    WHERE Over_Id BETWEEN 1 AND 6
    GROUP BY Match_Id, Team_Batting
) x
JOIN team t
    ON x.Team_Batting=t.Team_Id
GROUP BY t.Team_Name
ORDER BY Avg_Powerplay_Runs DESC;

-- Batting vs Bowling Efficiency Index
SELECT
    t.Team_Name,
    ROUND(SUM(b.Runs_Scored)/COUNT(DISTINCT b.Match_Id),2) AS Runs_Per_Match,
    ROUND(COUNT(w.Player_Out)/COUNT(DISTINCT b.Match_Id),2) AS Wickets_Per_Match
FROM team t
JOIN ball_by_ball b
    ON t.Team_Id=b.Team_Batting
LEFT JOIN wicket_taken w
    ON b.Match_Id=w.Match_Id
   AND b.Over_Id=w.Over_Id
   AND b.Ball_Id=w.Ball_Id
   AND b.Innings_No=w.Innings_No
GROUP BY t.Team_Name;

/*
Q13: Find the average wickets taken
by each bowler at every venue
and rank them.
*/

WITH Bowler_Avg_Wickets AS
(
    SELECT
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name,
        ROUND(
            COUNT(wt.Player_Out) * 1.0 /
            COUNT(DISTINCT m.Match_Id),
            2
        ) AS Avg_Wickets
    FROM ball_by_ball bb
    JOIN wicket_taken wt
        ON bb.Match_Id = wt.Match_Id
       AND bb.Innings_No = wt.Innings_No
       AND bb.Over_Id = wt.Over_Id
       AND bb.Ball_Id = wt.Ball_Id
    JOIN player p
        ON bb.Bowler = p.Player_Id
    JOIN matches m
        ON bb.Match_Id = m.Match_Id
    JOIN venue v
        ON m.Venue_Id = v.Venue_Id
    GROUP BY
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name
)
SELECT
    Player_Id,
    Player_Name,
    Venue_Name,
    Avg_Wickets,
    ROW_NUMBER() OVER (
        PARTITION BY Venue_Name
        ORDER BY Avg_Wickets DESC
    ) AS Wicket_Rank
FROM Bowler_Avg_Wickets
ORDER BY Venue_Name, Wicket_Rank;

/*
Q14: Which players have consistently
performed well across past seasons?
*/

SELECT
    p.Player_Name,
    s.Season_Year,
    SUM(b.Runs_Scored) AS Season_Runs
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
JOIN matches m
    ON b.Match_Id = m.Match_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
GROUP BY
    p.Player_Name,
    s.Season_Year
ORDER BY
    p.Player_Name,
    s.Season_Year;
    
SELECT
    p.Player_Name,
    ROUND(AVG(season_runs),2) AS Avg_Runs,
    ROUND(STDDEV(season_runs),2) AS Consistency_Score
FROM
(
    SELECT
        b.Striker,
        m.Season_Id,
        SUM(b.Runs_Scored) AS season_runs
    FROM ball_by_ball b
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    GROUP BY b.Striker, m.Season_Id
) x
JOIN player p
    ON x.Striker = p.Player_Id
GROUP BY p.Player_Name
HAVING AVG(season_runs) > 100
ORDER BY Consistency_Score ASC,
         Avg_Runs DESC;
         
SELECT
    p.Player_Name,
    SUM(b.Runs_Scored) AS Total_Runs
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
GROUP BY p.Player_Name
ORDER BY Total_Runs DESC
LIMIT 5;

SELECT
    p.Player_Name,
    s.Season_Year,
    SUM(b.Runs_Scored) AS Season_Runs
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
JOIN matches m
    ON b.Match_Id = m.Match_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE p.Player_Name IN (
    'AB de Villiers',
    'V Kohli',
    'DA Warner',
    'SK Raina',
    'RG Sharma'
)
GROUP BY
    p.Player_Name,
    s.Season_Year
ORDER BY
    p.Player_Name,
    s.Season_Year;
    
SELECT
    p.Player_Name,
    s.Season_Year,
    SUM(b.Runs_Scored) AS Season_Runs
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
JOIN matches m
    ON b.Match_Id = m.Match_Id
JOIN season s
    ON m.Season_Id = s.Season_Id
WHERE p.Player_Name IN (
    'AB de Villiers',
    'V Kohli',
    'DA Warner',
    'SK Raina',
    'RG Sharma'
)
GROUP BY
    p.Player_Name,
    s.Season_Year
ORDER BY
    p.Player_Name,
    s.Season_Year;
    
/*
Q15: Are there players whose performance is better at specific venues or conditions?
(how would you present this using charts?) 
*/ 

WITH Player_Venue_Runs AS (
    SELECT
        p.Player_Name,
        v.Venue_Name,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM ball_by_ball b
    JOIN player p
        ON b.Striker = p.Player_Id
    JOIN matches m
        ON b.Match_Id = m.Match_Id
    JOIN venue v
        ON m.Venue_Id = v.Venue_Id
    WHERE p.Player_Name IN (
        'V Kohli',
        'DA Warner',
        'AB de Villiers',
        'RG Sharma',
        'SK Raina'
    )
    GROUP BY p.Player_Name, v.Venue_Name
)
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY Player_Name
               ORDER BY Total_Runs DESC
           ) AS rn
    FROM Player_Venue_Runs
) x
WHERE rn <= 3
ORDER BY Player_Name, Total_Runs DESC;

/*
Subjective Q1: How does the toss decision
affect the match result?
Is the impact limited to specific venues?
*/

-- Overall Toss Impact
SELECT
    COUNT(*) AS Total_Matches,
    SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) AS Toss_And_Match_Won,
    ROUND(
        SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Toss_Impact_Percentage
FROM matches;

-- Bat First vs Field First
SELECT
    CASE
        WHEN Toss_Decide = 1 THEN 'Bat First'
        ELSE 'Field First'
    END AS Toss_Decision,
    COUNT(*) AS Matches,
    SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) AS Wins,
    ROUND(
        SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Win_Percentage
FROM matches
GROUP BY Toss_Decide;

-- Venue-wise Toss Impact
SELECT
    v.Venue_Name,
    COUNT(*) AS Matches,
    SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) AS Toss_And_Match_Won,
    ROUND(
        SUM(CASE WHEN m.Toss_Winner = m.Match_Winner THEN 1 ELSE 0 END) * 100.0
        / COUNT(*), 2
    ) AS Toss_Impact_Percentage
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
GROUP BY v.Venue_Name
HAVING COUNT(*) >= 5
ORDER BY Toss_Impact_Percentage DESC;

/*
Subjective Q2: Suggest players
who would be the best fit for the team.
*/

WITH Batting AS (
    SELECT
        b.Striker AS Player_Id,
        SUM(b.Runs_Scored) AS Total_Runs
    FROM ball_by_ball b
    GROUP BY b.Striker
),
Bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
        AND b.Innings_No = w.Innings_No
        AND b.Over_Id = w.Over_Id
        AND b.Ball_Id = w.Ball_Id
    GROUP BY b.Bowler
)
SELECT
    p.Player_Name,
    COALESCE(bt.Total_Runs,0) AS Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets
FROM player p
LEFT JOIN Batting bt
    ON p.Player_Id = bt.Player_Id
LEFT JOIN Bowling bw
    ON p.Player_Id = bw.Player_Id
WHERE COALESCE(bt.Total_Runs,0) > 1000
   OR COALESCE(bw.Total_Wickets,0) > 20
ORDER BY Total_Runs DESC, Total_Wickets DESC
LIMIT 15;

/*
Subjective Q3: What parameters should be
considered while selecting players?
*/

SELECT
    p.Player_Name,
    SUM(b.Runs_Scored) AS Total_Runs,
    ROUND((SUM(b.Runs_Scored) * 100.0) / COUNT(*), 2) AS Strike_Rate,
    COALESCE(wk.Total_Wickets, 0) AS Total_Wickets
FROM ball_by_ball b
JOIN player p
    ON b.Striker = p.Player_Id
LEFT JOIN (
    SELECT
        b.Bowler,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
        ON b.Match_Id = w.Match_Id
        AND b.Innings_No = w.Innings_No
        AND b.Over_Id = w.Over_Id
        AND b.Ball_Id = w.Ball_Id
    GROUP BY b.Bowler
) wk
    ON p.Player_Id = wk.Bowler
GROUP BY p.Player_Id, p.Player_Name, wk.Total_Wickets
HAVING SUM(b.Runs_Scored) > 500
ORDER BY Total_Runs DESC, Strike_Rate DESC;

/*
Subjective Q4: Which players offer versatility
by contributing effectively with both
bat and ball?
*/

WITH Batting AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
),
Bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
      ON b.Match_Id = w.Match_Id
     AND b.Innings_No = w.Innings_No
     AND b.Over_Id = w.Over_Id
     AND b.Ball_Id = w.Ball_Id
    GROUP BY b.Bowler
)
SELECT
    p.Player_Name,
    COALESCE(bt.Total_Runs,0) AS Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets
FROM player p
JOIN Batting bt
    ON p.Player_Id = bt.Player_Id
JOIN Bowling bw
    ON p.Player_Id = bw.Player_Id
WHERE bt.Total_Runs > 1000
  AND bw.Total_Wickets > 10
ORDER BY Total_Wickets DESC, Total_Runs DESC;

/*
Subjective Q5: Are there players whose presence
positively influences team morale
and performance?
*/

WITH MOTM AS (
    SELECT
        Man_of_the_Match AS Player_Id,
        COUNT(*) AS Man_Of_The_Match_Awards
    FROM matches
    GROUP BY Man_of_the_Match
),
RUNS AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
)
SELECT
    p.Player_Name,
    m.Man_Of_The_Match_Awards,
    COALESCE(r.Total_Runs,0) AS Total_Runs
FROM MOTM m
JOIN player p
    ON m.Player_Id = p.Player_Id
LEFT JOIN RUNS r
    ON p.Player_Id = r.Player_Id
ORDER BY m.Man_Of_The_Match_Awards DESC, Total_Runs DESC
LIMIT 10;

/*
Subjective Q6: What would you suggest
to RCB before the mega auction?
*/

WITH Batting AS (
    SELECT
        Striker AS Player_Id,
        SUM(Runs_Scored) AS Total_Runs
    FROM ball_by_ball
    GROUP BY Striker
),
Bowling AS (
    SELECT
        b.Bowler AS Player_Id,
        COUNT(w.Player_Out) AS Total_Wickets
    FROM ball_by_ball b
    JOIN wicket_taken w
      ON b.Match_Id = w.Match_Id
     AND b.Innings_No = w.Innings_No
     AND b.Over_Id = w.Over_Id
     AND b.Ball_Id = w.Ball_Id
    GROUP BY b.Bowler
)
SELECT
    p.Player_Name,
    COALESCE(bt.Total_Runs,0) AS Total_Runs,
    COALESCE(bw.Total_Wickets,0) AS Total_Wickets,
    (COALESCE(bt.Total_Runs,0) + (COALESCE(bw.Total_Wickets,0) * 20)) AS Player_Score
FROM player p
LEFT JOIN Batting bt
    ON p.Player_Id = bt.Player_Id
LEFT JOIN Bowling bw
    ON p.Player_Id = bw.Player_Id
ORDER BY Player_Score DESC
LIMIT 15;

/*
Subjective Q7: What factors contribute
to high-scoring matches, and what is
their impact on viewership and strategy?
*/

SELECT 
    v.Venue_Name,
    ROUND(AVG(bbb.Runs_Scored), 2) AS Avg_Runs_Per_Ball,
    ROUND(SUM(bbb.Runs_Scored) * 1.0 / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Total_Per_Match
FROM ball_by_ball bbb
JOIN matches m 
    ON bbb.Match_Id = m.Match_Id
JOIN venue v 
    ON m.Venue_Id = v.Venue_Id
GROUP BY v.Venue_Name
ORDER BY Avg_Total_Per_Match DESC;

/*
Subjective Q8: Analyze the impact of
home-ground advantage on RCB's performance.
*/

SELECT
    CASE
        WHEN v.Venue_Name = 'M Chinnaswamy Stadium'
        THEN 'Home Ground'
        ELSE 'Away Ground'
    END AS Venue_Type,
    COUNT(*) AS Matches_Played,
    SUM(
        CASE
            WHEN m.Match_Winner = (
                SELECT Team_Id
                FROM team
                WHERE Team_Name = 'Royal Challengers Bangalore'
            )
            THEN 1
            ELSE 0
        END
    ) AS Matches_Won,
    ROUND(
        SUM(
            CASE
                WHEN m.Match_Winner = (
                    SELECT Team_Id
                    FROM team
                    WHERE Team_Name = 'Royal Challengers Bangalore'
                )
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS Win_Percentage
FROM matches m
JOIN venue v
    ON m.Venue_Id = v.Venue_Id
WHERE (
    m.Team_1 = (
        SELECT Team_Id
        FROM team
        WHERE Team_Name = 'Royal Challengers Bangalore'
    )
    OR
    m.Team_2 = (
        SELECT Team_Id
        FROM team
        WHERE Team_Name = 'Royal Challengers Bangalore'
    )
)
GROUP BY Venue_Type;

-- Q11: In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of 
-- "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
DESC matches;

SELECT Team_Id, Team_Name
FROM team
WHERE Team_Name LIKE '%Delhi%';
































