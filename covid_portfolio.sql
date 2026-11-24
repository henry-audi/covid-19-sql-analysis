-- Preview the COVID-19 deaths and vaccination data.
SELECT *
FROM covid_deaths
WHERE NULLIF(TRIM(continent), '') IS NOT NULL
ORDER BY location, STR_TO_DATE(`date`, '%m/%d/%y');

SELECT *
FROM covid_vaccinations
ORDER BY location, STR_TO_DATE(`date`, '%m/%d/%y');


-- Looking at total cases vs. total deaths in Nigeria.
SELECT
    location,
    STR_TO_DATE(`date`, '%m/%d/%y') AS report_date,
    total_cases,
    total_deaths,
    100.0 * CAST(NULLIF(TRIM(total_deaths), '') AS SIGNED)
        / NULLIF(total_cases, 0) AS death_percentage
FROM covid_deaths
WHERE location = 'Nigeria'
ORDER BY report_date;


-- Looking at total cases compared to the population in Nigeria.
SELECT
    location,
    STR_TO_DATE(`date`, '%m/%d/%y') AS report_date,
    population,
    total_cases,
    100.0 * total_cases / NULLIF(population, 0)
        AS reported_cases_pct_of_population
FROM covid_deaths
WHERE location = 'Nigeria'
ORDER BY report_date;


-- Looking at countries with the highest case counts relative to population.
SELECT
    location,
    population,
    MAX(total_cases) AS highest_infection_count,
    100.0 * MAX(total_cases / NULLIF(population, 0))
        AS reported_cases_pct_of_population
FROM covid_deaths
WHERE NULLIF(TRIM(continent), '') IS NOT NULL
GROUP BY location, population
ORDER BY reported_cases_pct_of_population DESC;


-- Looking at countries with the highest recorded death counts.
SELECT
    location,
    MAX(CAST(NULLIF(TRIM(total_deaths), '') AS SIGNED)) AS total_death_count
FROM covid_deaths
WHERE NULLIF(TRIM(continent), '') IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC;


-- Looking at recorded death counts for continents and other regional totals.
SELECT
    location,
    MAX(CAST(NULLIF(TRIM(total_deaths), '') AS SIGNED)) AS total_death_count
FROM covid_deaths
WHERE NULLIF(TRIM(continent), '') IS NULL
GROUP BY location
ORDER BY total_death_count DESC;


-- Looking at global cases and deaths by date.
SELECT
    STR_TO_DATE(`date`, '%m/%d/%y') AS report_date,
    SUM(new_cases) AS total_cases,
    SUM(CAST(NULLIF(TRIM(new_deaths), '') AS SIGNED)) AS total_deaths,
    100.0 * SUM(CAST(NULLIF(TRIM(new_deaths), '') AS SIGNED))
        / NULLIF(SUM(new_cases), 0) AS death_percentage
FROM covid_deaths
WHERE NULLIF(TRIM(continent), '') IS NOT NULL
GROUP BY report_date
ORDER BY report_date;


-- Looking at global cases and deaths across all dates.
SELECT
    SUM(new_cases) AS total_cases,
    SUM(CAST(NULLIF(TRIM(new_deaths), '') AS SIGNED)) AS total_deaths,
    100.0 * SUM(CAST(NULLIF(TRIM(new_deaths), '') AS SIGNED))
        / NULLIF(SUM(new_cases), 0) AS death_percentage
FROM covid_deaths
WHERE NULLIF(TRIM(continent), '') IS NOT NULL;


-- Looking at vaccination doses compared to the population using a CTE.
WITH PopvsVac AS (
    SELECT
        d.continent,
        d.location,
        STR_TO_DATE(d.`date`, '%m/%d/%y') AS `date`,
        d.population,
        CAST(NULLIF(TRIM(v.new_vaccinations), '') AS SIGNED) AS new_vaccinations,
        SUM(CAST(NULLIF(TRIM(v.new_vaccinations), '') AS SIGNED)) OVER (
            PARTITION BY d.location
            ORDER BY STR_TO_DATE(d.`date`, '%m/%d/%y')
        ) AS running_total_doses
    FROM covid_deaths AS d
    JOIN covid_vaccinations AS v
        ON d.location = v.location
       AND d.`date` = v.`date`
    WHERE NULLIF(TRIM(d.continent), '') IS NOT NULL
)
SELECT
    *,
    100.0 * running_total_doses / NULLIF(population, 0) AS doses_per_100_residents
FROM PopvsVac
ORDER BY location, `date`;


-- Store the running vaccination totals in a temporary table.
DROP TEMPORARY TABLE IF EXISTS PercentPopulationVaccinatedTemp;

CREATE TEMPORARY TABLE PercentPopulationVaccinatedTemp (
    continent VARCHAR(255),
    location VARCHAR(255),
    `date` DATE,
    population BIGINT,
    new_vaccinations BIGINT,
    running_total_doses BIGINT
);

INSERT INTO PercentPopulationVaccinatedTemp (
    continent,
    location,
    `date`,
    population,
    new_vaccinations,
    running_total_doses
)
SELECT
    d.continent,
    d.location,
    STR_TO_DATE(d.`date`, '%m/%d/%y'),
    d.population,
    CAST(NULLIF(TRIM(v.new_vaccinations), '') AS SIGNED),
    SUM(CAST(NULLIF(TRIM(v.new_vaccinations), '') AS SIGNED)) OVER (
        PARTITION BY d.location
        ORDER BY STR_TO_DATE(d.`date`, '%m/%d/%y')
    )
FROM covid_deaths AS d
JOIN covid_vaccinations AS v
    ON d.location = v.location
   AND d.`date` = v.`date`
WHERE NULLIF(TRIM(d.continent), '') IS NOT NULL;

SELECT
    *,
    100.0 * running_total_doses / NULLIF(population, 0) AS doses_per_100_residents
FROM PercentPopulationVaccinatedTemp
ORDER BY location, `date`;


-- Create a view for the vaccination visualization.
CREATE OR REPLACE VIEW PercentPopulationVaccinated AS
SELECT
    d.continent,
    d.location,
    STR_TO_DATE(d.`date`, '%m/%d/%y') AS `date`,
    d.population,
    CAST(NULLIF(TRIM(v.new_vaccinations), '') AS SIGNED) AS new_vaccinations,
    SUM(CAST(NULLIF(TRIM(v.new_vaccinations), '') AS SIGNED)) OVER (
        PARTITION BY d.location
        ORDER BY STR_TO_DATE(d.`date`, '%m/%d/%y')
    ) AS running_total_doses
FROM covid_deaths AS d
JOIN covid_vaccinations AS v
    ON d.location = v.location
   AND d.`date` = v.`date`
WHERE NULLIF(TRIM(d.continent), '') IS NOT NULL;

SELECT
    *,
    100.0 * running_total_doses / NULLIF(population, 0) AS doses_per_100_residents
FROM PercentPopulationVaccinated
ORDER BY location, `date`;