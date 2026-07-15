library(tidycensus)
library(tidyverse)
library(janitor)
library(tigris)
library(sf)
library(sp)
library(scales)
library(hdatools)

rr <- c("51085", "51760", "51075", "51145", "51087", "51127", "51036", "51041")

# COMPONENTS OF POPULATION CHANGE

pep_change_raw <- get_estimates(
  geography = "county",
  state = "VA",
  variables = c("NATURALCHG", "DOMESTICMIG", "INTERNATIONALMIG"),
  time_series = TRUE
)


pep_change_clean <- pep_change_raw |> 
  filter(
    GEOID %in% rr,
    year > 2021
  ) |> 
  mutate(component = # Rename components of change
           case_when(
             variable == "NATURALCHG" ~ "Natural increase",
             variable == "DOMESTICMIG" ~ "Domestic migration",
             variable == "INTERNATIONALMIG" ~ "International migration")
         ) |> 
  summarise(
    value = sum(value),
    .by = c(year, component)
  )

pep_change_clean |> 
  ggplot(aes(x = year, y = value, fill = component)) +
  geom_col() +
  geom_text(
    aes(label = label_comma()(value)),
    position = position_stack(vjust = 0.5),
    size = 20,
    color = "white",
    alpha = 0.8
  ) +
  scale_y_continuous(labels = label_comma()) +
  scale_fill_pha() +
  theme_pha(base_size = 50) +
  theme(
    legend.position = "right",
    legend.text = element_text(size = 50),
    legend.key.spacing.y = unit(1, "cm")
  ) +
  add_zero_line("y")

ggsave("img/pop_comp_chg.png", width = 10, height = 4.94, units = "in", bg = "white")


# HOUSEHOLD TYPES

years <- 2021:2023

b11001_vars <- load_variables(2023, "acs5") |>
  filter(str_sub(name, end = 7) %in% "B11001_")

b11001_vars_cleaned <- b11001_vars |>
  separate(label, into = c("est", "tot", "type", "relationship", "householder"),
           sep = "!!") |>
  select(variable = name, type, relationship, householder) |>
  mutate(
    householder = case_when(
      relationship == "Married-couple family" ~ relationship,
      relationship == "Householder living alone" ~ relationship,
      relationship == "Householder not living alone" ~ relationship,
      TRUE ~ householder),
    relationship = case_when(
      relationship == "Householder living alone" ~ type,
      relationship == "Householder not living alone" ~ type,
      TRUE ~ relationship)
  ) |>
  mutate(across(.fns = ~str_remove_all(.x, ":"))) |>
  drop_na()

b11001_raw <- map_dfr(years, function(yr){
  b11001_pull <- get_acs(
    geography = "county",
    state = "VA",
    table = "B11001",
    year = yr,
    survey = "acs5",
    cache_table = TRUE
  ) |>
    mutate(year = yr)
})

b11001_raw <- b11001_raw |>
  subset(GEOID %in% rr)

b11001_data <- b11001_raw |>
  right_join(b11001_vars_cleaned, by = "variable") |>
  select(NAME, GEOID, year, "hhtype" = householder, relationship, type, estimate) |>
  mutate(NAME = str_remove_all(NAME, ", Virginia")) |>
  pivot_wider(names_from = year,
              values_from = estimate) |>
  select(NAME, hhtype, `2021`, `2023`) |>
  transform(change = `2023` - `2021`) |>
  group_by(hhtype) |>
  summarise(change = sum(change))

ggplot(b11001_data,
       aes(x = reorder(hhtype, -change),
           y = change,
           fill = hhtype)) +
  geom_col() + 
  geom_text(
    #data = filter(b11001_data, change > 1000),
    aes(
      x = reorder(hhtype, -change),
      y = change - 250,
      label = label_comma()(change)),
    size = 18,
    color = "white"
  ) +
  scale_y_continuous(labels = label_comma()) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 16)) +
  scale_fill_pha(direction = -1) +
  theme_pha(base_size = 50) +
  add_zero_line("y") +
  theme(
    axis.text.x = element_text(lineheight = 0.3)
  )

ggsave("img/hh_type_chg.png", width = 10, height = 4.94, units = "in", bg = "white")

