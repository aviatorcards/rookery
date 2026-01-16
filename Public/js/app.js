// Rookery Client-Side JavaScript

// Global state for language filter (must be declared before use)
var currentLanguageFilter = null;

// Language filter handler - must be defined early for inline onclick
function handleLanguageClick(buttonElement, language) {
  // Update active state
  var allButtons = document.querySelectorAll(".language-item");
  for (var i = 0; i < allButtons.length; i++) {
    allButtons[i].classList.remove("active");
  }
  buttonElement.classList.add("active");

  // Set filter
  currentLanguageFilter = language;

  // Filter the snippet cards
  var cards = document.querySelectorAll(".snippet-card");
  for (var j = 0; j < cards.length; j++) {
    var card = cards[j];
    var cardLanguage = card.getAttribute("data-language");

    if (language === null) {
      card.style.display = "";
    } else if (cardLanguage && cardLanguage.toLowerCase() === language.toLowerCase()) {
      card.style.display = "";
    } else {
      card.style.display = "none";
    }
  }

  // Update the header
  var headerH2 = document.querySelector(".header-actions h2");
  if (headerH2) {
    if (language === null) {
      headerH2.textContent = "All Snippets";
    } else {
      headerH2.textContent = language.charAt(0).toUpperCase() + language.slice(1) + " Snippets";
    }
  }

  // Clear search
  var searchInput = document.getElementById("searchInput");
  if (searchInput) {
    searchInput.value = "";
  }
}

// Modal Management
function showCreateModal() {
  document.getElementById("createModal").style.display = "block";
}

function hideCreateModal() {
  document.getElementById("createModal").style.display = "none";
  document.getElementById("createForm").reset();
}

// Close modal when clicking outside
window.onclick = function (event) {
  const modal = document.getElementById("createModal");
  if (event.target === modal) {
    hideCreateModal();
  }
};

// Create Snippet
async function createSnippet(event) {
  event.preventDefault();

  const title = document.getElementById("title").value;
  const language = document.getElementById("language").value;
  const code = document.getElementById("code").value;
  const description = document.getElementById("description").value || null;
  const tagsInput = document.getElementById("tags").value;
  const tags = tagsInput ? tagsInput.split(",").map((t) => t.trim()) : [];
  const isFavorite = document.getElementById("isFavorite").checked;

  try {
    const response = await fetch("/api/snippets", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        title,
        language,
        code,
        description,
        tags,
        isFavorite,
      }),
    });

    if (response.ok) {
      hideCreateModal();
      window.location.reload();
    } else {
      alert("Failed to create snippet");
    }
  } catch (error) {
    console.error("Error:", error);
    alert("Failed to create snippet");
  }
}

// Delete Snippet
async function deleteSnippet(id) {
  if (!confirm("Are you sure you want to delete this snippet?")) {
    return;
  }

  try {
    const response = await fetch(`/api/snippets/${id}`, {
      method: "DELETE",
    });

    if (response.ok) {
      window.location.reload();
    } else {
      alert("Failed to delete snippet");
    }
  } catch (error) {
    console.error("Error:", error);
    alert("Failed to delete snippet");
  }
}

// Generate Freeze Image
async function generateFreeze(id) {
  const theme = prompt(
    "Enter theme (default: catppuccin-mocha):",
    "catppuccin-mocha"
  );
  if (!theme) return;

  try {
    const response = await fetch(
      `/api/snippets/${id}/freeze?theme=${theme}&format=png`
    );

    if (response.ok) {
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `snippet-${id}.png`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } else {
      alert(
        "Failed to generate image. Make sure freeze is installed: brew install charmbracelet/tap/freeze"
      );
    }
  } catch (error) {
    console.error("Error:", error);
    alert("Failed to generate image");
  }
}

// Search Snippets
function searchSnippets() {
  var input = document.getElementById("searchInput");
  var filter = input.value.toLowerCase();
  var cards = document.querySelectorAll(".snippet-card");

  for (var i = 0; i < cards.length; i++) {
    var card = cards[i];
    var title = card.querySelector("h3").textContent.toLowerCase();
    var descEl = card.querySelector(".snippet-description");
    var description = descEl ? descEl.textContent.toLowerCase() : "";
    var tags = (card.getAttribute("data-tags") || "").toLowerCase();
    var cardLanguage = (card.getAttribute("data-language") || "").toLowerCase();

    // Check if matches search
    var matchesSearch =
      filter === "" ||
      title.indexOf(filter) !== -1 ||
      description.indexOf(filter) !== -1 ||
      tags.indexOf(filter) !== -1 ||
      cardLanguage.indexOf(filter) !== -1;

    // Check if matches language filter
    var matchesLanguage =
      currentLanguageFilter === null ||
      cardLanguage === currentLanguageFilter.toLowerCase();

    if (matchesSearch && matchesLanguage) {
      card.style.display = "";
    } else {
      card.style.display = "none";
    }
  }
}

// Sort Snippets
function sortSnippets(criteria) {
  const grid = document.getElementById("snippetsGrid");
  const cards = Array.from(grid.getElementsByClassName("snippet-card"));

  cards.sort((a, b) => {
    let valA, valB;

    switch (criteria) {
      case "language":
        valA = a.dataset.language.toLowerCase();
        valB = b.dataset.language.toLowerCase();
        break;
      case "title":
        valA = a.querySelector("h3").textContent.toLowerCase();
        valB = b.querySelector("h3").textContent.toLowerCase();
        break;
      default: // original order (likely mostly by ID or created_at if DB returns it that way)
        return 0;
    }

    if (valA < valB) return -1;
    if (valA > valB) return 1;
    return 0;
  });

  // Re-append to grid in new order
  cards.forEach((card) => grid.appendChild(card));
}

// Freeze Modal Management
let currentSnippetIdForFreeze = null;

function showFreezeModal(id) {
  currentSnippetIdForFreeze = id;
  document.getElementById("freezeModal").style.display = "block";
}

function hideFreezeModal() {
  document.getElementById("freezeModal").style.display = "none";
  currentSnippetIdForFreeze = null;
}

// Close modal when clicking outside
window.onclick = function (event) {
  const createModal = document.getElementById("createModal");
  const freezeModal = document.getElementById("freezeModal");

  if (event.target === createModal) {
    hideCreateModal();
  }
  if (event.target === freezeModal) {
    hideFreezeModal();
  }
};

async function submitFreeze(event) {
  event.preventDefault();
  if (!currentSnippetIdForFreeze) return;

  const theme = document.getElementById("freezeTheme").value;
  const windowControls = document.getElementById("freezeWindow").checked;
  const showBackground = document.getElementById("freezeBackground").checked;
  const showLineNumbers = document.getElementById("freezeLineNumbers").checked;
  const padding = document.getElementById("freezePadding").value;
  const margin = document.getElementById("freezeMargin").value;

  const queryParams = new URLSearchParams({
    theme,
    window: windowControls,
    background: showBackground,
    showLineNumbers,
    padding,
    margin,
    format: "png",
  });

  const btn = event.submitter;
  const originalText = btn.textContent;
  btn.textContent = "Generating...";
  btn.disabled = true;

  try {
    const response = await fetch(
      `/api/snippets/${currentSnippetIdForFreeze}/freeze?${queryParams.toString()}`
    );

    if (response.ok) {
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `snippet-${currentSnippetIdForFreeze}.png`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
      hideFreezeModal();
    } else {
      alert("Failed to generate image.");
    }
  } catch (error) {
    console.error("Error:", error);
    alert("Failed to generate image");
  } finally {
    btn.textContent = originalText;
    btn.disabled = false;
  }
}

// Update the old generateFreeze to just open the modal
function generateFreeze(id) {
  showFreezeModal(id);
}

// Language Filter from Sidebar
// Handler for inline onclick - called directly from HTML buttons
function handleLanguageClick(buttonElement, language) {
  console.log("handleLanguageClick called:", language);
  filterByLanguage(language);

  // Update active state
  var allButtons = document.querySelectorAll(".language-item");
  for (var i = 0; i < allButtons.length; i++) {
    allButtons[i].classList.remove("active");
  }
  buttonElement.classList.add("active");
}

function filterByLanguage(language) {
  console.log("filterByLanguage called with:", language);
  currentLanguageFilter = language;

  // Filter the snippet cards
  var cards = document.querySelectorAll(".snippet-card");
  console.log("Found " + cards.length + " snippet cards");

  for (var j = 0; j < cards.length; j++) {
    var card = cards[j];
    var cardLanguage = card.getAttribute("data-language");
    console.log("Card " + j + " language: " + cardLanguage);

    if (language === null) {
      card.style.display = "";
    } else if (cardLanguage && cardLanguage.toLowerCase() === language.toLowerCase()) {
      card.style.display = "";
    } else {
      card.style.display = "none";
    }
  }

  // Update the header to show filtered state
  var headerH2 = document.querySelector(".header-actions h2");
  if (headerH2) {
    if (language === null) {
      headerH2.textContent = "All Snippets";
    } else {
      headerH2.textContent = language.charAt(0).toUpperCase() + language.slice(1) + " Snippets";
    }
  }

  // Clear search when filtering by language
  var searchInput = document.getElementById("searchInput");
  if (searchInput) {
    searchInput.value = "";
  }
}

// Initialize language filter click handlers
function initLanguageFilter() {
  var buttons = document.querySelectorAll(".language-item");
  console.log("initLanguageFilter: Found " + buttons.length + " language buttons");

  if (buttons.length === 0) {
    console.log("No language buttons found - sidebar may not be loaded");
    return;
  }

  for (var i = 0; i < buttons.length; i++) {
    (function(button) {
      button.addEventListener("click", function(e) {
        e.preventDefault();
        e.stopPropagation();
        var lang = button.getAttribute("data-language");
        console.log("Language button clicked: " + lang);
        if (lang === "all") {
          filterByLanguage(null);
        } else {
          filterByLanguage(lang);
        }
      });
    })(buttons[i]);
  }
  console.log("Language filter initialized successfully");
}

// Run when DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initLanguageFilter);
} else {
  // DOM already loaded, run immediately
  initLanguageFilter();
}
