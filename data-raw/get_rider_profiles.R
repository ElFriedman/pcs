library(dplyr)
library(stringr)
library(rvest)
library(xml2)
library(tidyr)

get_profs <- function(url){
  site <- read_html(url)
  current_rankings <- 
    site %>% 
    html_nodes(xpath = '//*[contains(concat( " ", @class, " " ), concat( " ", "statDivLeft", " " ))]') %>% 
    html_nodes("table") %>% 
    {. ->> raw_table} %>% 
    .[[1]] %>% 
    html_table() %>% 
    dplyr::select(-7) %>% 
    mutate(`Diff.` = as.numeric(ifelse(str_detect(`Diff.`,"\\u25B2"), 
                                       str_remove(`Diff.`, "\\u25B2"),
                                       ifelse(str_detect(`Diff.`,"\\u25BC"), 
                                              str_replace(`Diff.`, "\\u25BC","-"),
                                              ifelse(str_detect(`Diff.`,"-"),
                                                     0,
                                                     `Diff.`)))))
  
  
  url_list <- raw_table %>% 
    html_nodes(., "a") %>% 
    html_attr(., "href") %>% 
    as_tibble() %>% 
    filter(str_detect(value, "rider/|team/")) %>% 
    separate(value, c("var","url"), "/")
  
  rider_urls <- url_list %>% 
    filter(var == "rider") %>% 
    dplyr::pull(url)
  
  rider_profiles <- NULL
  for (i in 1:length(rider_urls)){
    Sys.sleep(0.5)
    url <- paste0("https://www.procyclingstats.com/rider/",rider_urls[i])
    rider_html <- read_html(url) 
    
    rider_metadata <- 
      rider_html %>% 
      html_nodes('h1') %>% 
      html_text() %>% 
      str_split(.,"»")
    
    rider <- str_squish(rider_metadata[[1]][1])
    message(rider)
    team <- str_squish(rider_metadata[[1]][2])
    
    jumbled <- rider_html %>% 
      html_nodes(".rdr-info-cont") %>%
      html_text()

    if (str_detect(jumbled, "Date of birth:")){
      dob <- jumbled %>% 
        str_extract("(?<=:).*(?=\\()") %>% 
        str_remove("th|nd|rd|st") %>% 
        str_squish() %>% 
        as.Date(., format = "%d %B %Y")
    } else {
      dob <- NA
    }

    if (str_detect(jumbled, "Nationality")){
      nationality <- jumbled %>% 
        str_extract("(?<=Nationality: )([A-Z][a-z]*)")
    } else {
      nationality <- NA
    }
    
    if (str_detect(jumbled, "Weight")){
      weight <- jumbled %>% 
        str_extract("(?<=Weight: ).*(?= kg)")
    } else {
      weight <- NA
    }
    
    if (str_detect(jumbled, "Height")){
      height <- jumbled %>% 
        str_extract("(?<=Height: ).*(?= m)")
    } else {
      height <- NA
    }
    
    if (str_detect(jumbled, "Place of birth:")){
      pob <- jumbled %>% 
        str_extract("(?<=Place of birth: ).*(?=Points)|(?=One)")
    } else {
      pob <- NA
    }
    
    one_day_races <- jumbled %>% 
      str_extract("(?<=Points per specialty).*(?=One day races)")
    
    gc <- jumbled %>% 
      str_extract("(?<=One day races).*(?=GC)")
    
    tt <- jumbled %>% 
      str_extract("(?<=GC).*(?=Time trial)")
    
    sprint <- jumbled %>% 
      str_extract("(?<=Time trial).*(?=Sprint)")
    
    climber <- jumbled %>% 
      str_extract("(?<=Sprint).*(?=Climber)")
    
    
    out <- tibble(rider = rider,
                  dob = dob,
                  nationality = nationality,
                  pob = pob,
                  current_team = team,
                  weight = as.numeric(weight),
                  height = as.numeric(height),
                  one_day_races = as.numeric(one_day_races),
                  gc = as.numeric(gc),
                  tt = as.numeric(tt),
                  sprint = as.numeric(sprint),
                  climber = as.numeric(climber))
    
    assign('rider_profiles', rbind(out, rider_profiles))
  }
  
  return(rider_profiles)
}

rider_profiles_men <- get_profs(url = "https://www.procyclingstats.com/rankings.php?id=59874&nation=&team=&page=0&prev_id=prev&younger=&older=&limit=200&filter=Filter&morefilters=")
rider_profiles_women <- get_profs(url = "https://www.procyclingstats.com/rankings.php?id=59898&nation=&team=&page=0&prev_id=prev&younger=&older=&limit=200&filter=Filter&morefilters=")

usethis::use_data(rider_profiles_men,
                  rider_profiles_women,
                  overwrite = TRUE)

