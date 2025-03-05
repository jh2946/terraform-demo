function deckGenerator(id, title, description) {
    const newDiv = document.createElement('div')
    newDiv.classList.add('deck-thumbnail')
    newDiv.innerHTML = `
        <a href="deck.html?id=${id}" class="deck-clickable">
            <div class="card-outline"></div>
            <div class="card-outline"></div>
            <div class="card-outline"></div>
            <div class="card-outline">
                <div class="card-text">
                    <div class="card-text-bound">
                        <div>
                            <h1 class="title-target"></h1>
                            <p class="description-target"></p>
                        </div>
                    </div>
                </div>
            </div>
        </a>
    `
    const titleTarget = newDiv.getElementsByClassName('title-target')[0]
    titleTarget.append(title)

    const descriptionTarget = newDiv.getElementsByClassName('description-target')[0]
    descriptionTarget.append(description)

    return newDiv
}

const deckList = document.getElementById('deck-list')

fetch('endpoint').then(res => {
    return res.json()
}).then(data => {
    for (const deck of data) {
        const meta = JSON.parse(deck.meta)
        deckList.append(
            deckGenerator(
                deck.id,
                meta.title,
                meta.description
            )
        )
    }
})
