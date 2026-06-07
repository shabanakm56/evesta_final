def get_event_deteils_web():
    from selenium import webdriver
    from selenium.webdriver.chrome.service import Service
    from webdriver_manager.chrome import ChromeDriverManager
    from bs4 import BeautifulSoup
    import time

    # ==========================
    # START BROWSER
    # ==========================
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()))

    url = "https://in.bookmyshow.com/explore/events-kozhikode"
    driver.get(url)

    # Wait for page to load
    time.sleep(6)

    html = driver.page_source
    soup = BeautifulSoup(html, "html.parser")

    print("\nNearest Events:\n")

    events = soup.find_all("a", href=True)

    count = 0
    results=[]
    for event in events:
        title = event.get_text(strip=True)
        link = event.get("href")

        # find image inside event card
        img = event.find("img")
        img_link = None

        if img:
            img_link = img.get("src")

        if title and len(title) > 15:
            if link and link.startswith("/"):
                link = "https://in.bookmyshow.com" + link

            print("Event:", title)
            print("Event Link:", link)
            print("Image Link:", img_link)
            print("-" * 60)
            results.append({"title":title,"link":link,"img_link":img_link})
            count += 1

        if count >= 5:
            break

    driver.quit()
    return results



