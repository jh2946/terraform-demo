const form = document.getElementById('deck-form')
const createCard = document.getElementById('create-card')
const fullscreenForm = document.getElementById('fullscreen-form')
const textFront = document.getElementById('text-front')
const textBack = document.getElementById('text-back')

form.action += location.search

function cardFaceGenerator(text, imagesrc) {
    const cardOverlay = document.createElement('div')
    cardOverlay.classList.add('card-overlay')
    if (imagesrc) {
        cardOverlay.innerHTML = `
            <div class="half-card">
                <div class="card-image">
                    <img src="${imagesrc}" alt="card image">
                </div>
            </div>
            <div class="half-card">
                <div class="card-text"></div>
            </div>
        `
    }
    else {
        cardOverlay.innerHTML = `
            <div class="card-text"></div>
        `
    }
    if (text) {
        const textDiv = cardOverlay.getElementsByClassName('card-text')[0]
        textDiv.append(text)
    }
    return cardOverlay
}

function cardGenerator(data) {
    const newCard = document.createElement('div')
    newCard.classList.add('card-outer')
    newCard.innerHTML = `
        <div class="card">
            <div class="card-front"></div>
            <div class="card-back"></div>
        </div>
    `

    const cardFront = newCard.getElementsByClassName('card-front')[0]
    cardFront.append(cardFaceGenerator(
        data['text-front'],
        data['file-front']
    ))

    const cardBack = newCard.getElementsByClassName('card-back')[0]
    cardBack.append(cardFaceGenerator(
        data['text-back'],
        data['file-back']
    ))

    enableFlip(newCard.children[0])

    return newCard
}

const cardList = document.getElementById('card-list')
fetch('deck/endpoint' + location.search).then(res => {
    return res.json()
}).then(data => {
    for (const cardData of data) {
        cardList.append(cardGenerator(
            JSON.parse(cardData.meta)
        ))
    }
})

createCard.onclick = () => {
    fullscreenForm.style.display = 'flex'
    textFront.focus()
}

const formFront = document.getElementById('form-front')
const formBack = document.getElementById('form-back')

const formNextButton = document.getElementById('next-button')
function formNext() {
    formFront.style.display = 'none'
    formBack.style.display = 'block'
    textBack.focus()
}
formNextButton.onclick = formNext

const formBackButton = document.getElementById('back-button')
function formPrev() {
    formFront.style.display = 'block'
    formBack.style.display = 'none'
    textFront.focus()
}
formBackButton.onclick = formPrev

const zoneFront = document.getElementById('zone-front')
const fileFront = document.getElementById('file-front')
const zoneBack = document.getElementById('zone-back')
const fileBack = document.getElementById('file-back')

function addToZone(zone, input) {
    const reader = new FileReader()
    reader.onload = e => {
        const imgElm = zone.getElementsByClassName('zone-img')[0]
        const placeholder = zone.getElementsByClassName('dropzone-placeholder')[0]
        placeholder.style.display = 'none'
        imgElm.src = e.target.result
    }
    reader.readAsDataURL(input.files[0])
}

fileFront.oninput = () => addToZone(zoneFront, fileFront)
fileBack.oninput = () => addToZone(zoneBack, fileBack)

const clearFront = document.getElementById('clear-front')
const clearBack = document.getElementById('clear-back')

function clearZone(event, zone, input) {
    event.preventDefault()
    input.value = null
    const imgElm = zone.getElementsByClassName('zone-img')[0]
    imgElm.src = ''
    const placeholder = zone.getElementsByClassName('dropzone-placeholder')[0]
    placeholder.style.display = 'block'
    verifyInputs()
}

clearFront.onclick = event => clearZone(event, zoneFront, fileFront)
clearBack.onclick = event => clearZone(event, zoneBack, fileBack)

const formXButton = document.getElementById('form-x')
function cancelForm() {
    fullscreenForm.style.display = 'none'
}

formXButton.onclick = cancelForm

addEventListener('keydown', event => {
    if (event.ctrlKey && fullscreenForm.style.display == 'flex') {
        if (event.key == 'ArrowRight') formNext()
        else if (event.key == 'ArrowLeft') formPrev()
        else if (event.key == 'Enter') {
            if (formBack.style.display == 'block') form.submit()
        }
    }
    if (event.key == 'Escape') cancelForm()
})

const submitBtn = document.getElementById('submit-btn')

function verifyInputs() {
    if ((textFront.value || fileFront.value) &&
    (textBack.value || fileBack.value)) submitBtn.removeAttribute('disabled')
    else submitBtn.setAttribute('disabled', '')
}
verifyInputs()
textFront.oninput = verifyInputs
textBack.oninput = verifyInputs
fileFront.oninput = () => {
    addToZone(zoneFront, fileFront)
    verifyInputs()
}
fileBack.oninput = () => {
    addToZone(zoneBack, fileBack)
    verifyInputs()
}
