library(tidyverse)
library(janitor)
library(scales)
library(hdatools)
library(readxl)

pha_pal <- c(
  "#5bab8e", # Green
  "#a6cccc", # Light Blue
  "#f39152", # Orange
  "#be451c", # Red
  "#a5add0", # Purple
  "#2b6b9c"  # Dark Blue
)

# RENTAL MARKET

costar_raw <- read_xlsx("data/costar_multifamily_data.xlsx") |> 
  clean_names()

costar <- costar_raw |> 
  mutate(year = as.numeric(str_sub(period, 1, 4))) |> 
  filter(year %in% 2020:2025) |> 
  arrange(period)

ggplot(costar, aes(x = period)) +
  geom_col(
    aes(y = under_construction_units, group = 1),
    fill = pha_pal[1],
    alpha = 0.8
  ) +
  geom_col(
    aes(y = deliveries_units, group = 1),
    fill = pha_pal[6],
    width = 0.6
  ) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 4)) +
  scale_y_continuous(
    breaks = c(2500, 5000, 7500, 10000, 12500),
    labels = label_comma(),
    expand = c(0.01, 0.05)
  ) +
  add_zero_line("y") +
  theme_pha(base_size = 60) +
  theme(
    axis.text.x = element_text(size = 30, lineheight = 0.3)
  )

ggsave("img/mf_production.png", width = 12, height = 4.94, units = "in", bg = "white")

coeff <- 10000

costar |> 
  select(period, asking_rent_per_unit, vacancy_percent) |> 
  pivot_longer(
    cols = 2:3,
    names_to = "var",
    values_to = "val"
  )

ggplot(costar, aes(x = period)) +
  geom_line(
    aes(y = asking_rent_per_unit, group = 1),
    color = pha_pal[1],
    linewidth = 1.5
  ) +
  geom_line(
    aes(y = vacancy_percent*coeff, group = 1),
    color = pha_pal[6],
    linewidth = 1.5
  ) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 4)) +
  scale_y_continuous(
    name = "Rent",
    limits = c(200, 1700),
    labels = label_dollar(),
    expand = c(0.01, 0.05),
    sec.axis = sec_axis(
      ~./coeff, name = "Vacancy",
      labels = label_percent()
    )
  ) +
  #add_zero_line("y") +
  theme_pha(base_size = 60) +
  theme(
    axis.text.x = element_text(size = 30, lineheight = 0.3),
    axis.text.y.left = element_text(color = pha_pal[1]),
    axis.text.y.right = element_text(color = pha_pal[6], hjust = 0)
  )

ggsave("img/mf_rent_vac.png", width = 12, height = 4.94, units = "in", bg = "white")
