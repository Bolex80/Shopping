package handlers

import (
	"log"
	"shopping-list/db"
	"sync"
	"time"
)

var autoArchiveMu sync.Mutex

// StartAutoArchiveScheduler starts a background goroutine that checks
// every 5 minutes whether a new week or month has started, and if so,
// automatically archives all completed items across all lists.
// It also runs an immediate check on startup to catch up after downtime.
func StartAutoArchiveScheduler() {
	go runAutoArchiveCheck()

	ticker := time.NewTicker(5 * time.Minute)
	go func() {
		defer ticker.Stop()
		for range ticker.C {
			runAutoArchiveCheck()
		}
	}()
}

func runAutoArchiveCheck() {
	autoArchiveMu.Lock()
	defer autoArchiveMu.Unlock()

	now := time.Now()

	currentWeek := now.Format("2006-W02")
	currentMonth := now.Format("2006-01")

	lastWeeklyWeek, lastMonthlyMonth, _, err := db.GetAutoArchiveState()
	if err != nil {
		log.Println("AutoArchive: failed to read state:", err)
		return
	}

	archiveNeeded := false

	if currentWeek != lastWeeklyWeek {
		log.Printf("AutoArchive: new week detected (%s vs %s)", currentWeek, lastWeeklyWeek)
		archiveNeeded = true
	}

	if currentMonth != lastMonthlyMonth {
		log.Printf("AutoArchive: new month detected (%s vs %s)", currentMonth, lastMonthlyMonth)
		archiveNeeded = true
	}

	if !archiveNeeded {
		return
	}

	// Only archive lists where 100% of items are completed
	listIDs, err := db.GetFullyCompletedListIDs()
	if err != nil {
		log.Println("AutoArchive: failed to query fully completed lists:", err)
		return
	}

	if len(listIDs) == 0 {
		log.Println("AutoArchive: no fully completed lists, nothing to archive")
	} else {
		var totalArchived int64
		for _, listID := range listIDs {
			count, err := db.ArchiveCompletedItems(listID)
			if err != nil {
				log.Printf("AutoArchive: failed to archive list %d: %v", listID, err)
				continue
			}
			totalArchived += count
			log.Printf("AutoArchive: archived %d items from list %d", count, listID)
			BroadcastUpdate("auto_archive_completed", map[string]interface{}{
				"archived": count,
				"list_id":  listID,
				"week":     currentWeek,
				"month":    currentMonth,
			})
		}
		if totalArchived > 0 {
			log.Printf("AutoArchive: total archived %d completed items from %d lists", totalArchived, len(listIDs))
		}
	}

	if err := db.SetAutoArchiveState(currentWeek, currentMonth, now.Unix()); err != nil {
		log.Println("AutoArchive: failed to update state:", err)
	}
}
