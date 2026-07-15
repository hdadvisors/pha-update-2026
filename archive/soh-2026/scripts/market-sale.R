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

# FOR-SALE MARKET

mls <- read_csv("data/mls_combined.csv") |> 
  mutate(date = ymd(paste(year, month, "01", sep = "-")))

mls |> 
  filter(year > 2022, metric == "active_listings") |> 
  ggplot(aes(x = date, y = value)) +
  geom_area(
    fill = pha_pal[1],
    alpha = 0.8
  ) +
  geom_hline(yintercept = 2206, linewidth = 1) +
  geom_hline(yintercept = 3891, linewidth = 1) +
  scale_y_continuous(
    expand = c(0.01,0.05),
    labels = label_comma()
  ) +
  scale_x_date(
    expand = c(0.025,0.025),
    date_breaks = "3 months",
    #date_minor_breaks = "1 month",
    date_labels = "%Y\n%b"
  ) +
  add_zero_line("y") +
  theme_pha(base_size = 60) +
  theme(
    axis.text.x = element_text(size = 30, lineheight = 0.3)
  )

ggsave("img/mls_act_list.png", width = 12, height = 4.94, units = "in", bg = "white")

coeff <- 0.01

mls |> 
  filter(year > 2021, metric %in% c("days_to_sell", "median_sale_price")) |> 
  pivot_wider(
    names_from = metric,
    values_from = value
  ) |> 
  arrange(date) |>
  mutate(
    yoy_chg = (median_sale_price - lag(median_sale_price, 11)) / lag(median_sale_price, 11)
  ) |> 
  filter(year > 2022) |> 
  ggplot(aes(x = date)) +
  geom_line(
    aes(y = yoy_chg),
    color = pha_pal[1],
    linewidth = 1.5
  ) +
  geom_line(
    aes(y = days_to_sell*coeff, group = 1),
    color = pha_pal[6],
    linewidth = 1.5
  ) +
  scale_x_date(
    expand = c(0.025,0.025),
    date_breaks = "3 months",
    #date_minor_breaks = "1 month",
    date_labels = "%Y\n%b"
  ) +
  scale_y_continuous(
    name = "MSP",
    #limits = c(0, 470000),
    labels = label_percent(),
    expand = c(0.01, 0.05),
    sec.axis = sec_axis(
      ~./coeff, name = "DTS"
      #labels = label_percent()
    )
  ) +
  #add_zero_line("y") +
  theme_pha(base_size = 60) +
  theme(
    axis.text.x = element_text(size = 30, lineheight = 0.3),
    axis.text.y.left = element_text(color = pha_pal[1]),
    axis.text.y.right = element_text(color = pha_pal[6], hjust = 0)
  )
  

ggsave("img/mls_sales.png", width = 12, height = 4.94, units = "in", bg = "white")

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


ggplot(costar, aes(x = period)) +
  geom_line(
    aes(y = asking_rent_percent_growth_yr, group = 1),
    color = pha_pal[1],
    linewidth = 1.5
  ) +
  geom_line(
    aes(y = vacancy_percent, group = 1),
    color = pha_pal[6],
    linewidth = 1.5
  ) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 4)) +
  scale_y_continuous(
    limits = c(0.01, 0.10),
    breaks = c(0.025, 0.05, 0.075, 0.1),
    labels = label_percent(),
    expand = c(0, 0.01),
    sec.axis = sec_axis(
      ~.,
      labels = label_percent(),
      breaks = c(0.025, 0.05, 0.075, 0.1)
    )
  ) +
  #add_zero_line("y") +
  theme_pha(base_size = 60) +
  theme(
    axis.text.x = element_text(size = 30, lineheight = 0.3),
    axis.text.y.left = element_text(color = pha_pal[1]),
    axis.text.y.right = element_text(color = pha_pal[6], hjust = 0)
  )

ggsave("img/mf_rent_growth_vac.png", width = 12, height = 4.94, units = "in", bg = "white")
