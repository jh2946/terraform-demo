const fullscreen = document.getElementById('fullscreen-img-cont')
const fullImage = document.getElementById('fullscreen-img')

function enableFlip(card) {
    card.onclick = () => {
        if (card.style.transform == 'rotateY(180deg)')
            card.style.transform = ''
        else
            card.style.transform = 'rotateY(180deg)'
    }

    const images = card.getElementsByClassName('card-image')

    for (const imageCont of images) {
        imageCont.onclick = event => {
            event.stopPropagation()
            const image = imageCont.children[0]
            fullImage.src = image.src
            fullscreen.style.display = 'block'
        }
    }
}

const cancelBtn = document.getElementById('x')
function cancel() {
    fullImage.src = ''
    fullscreen.style.display = 'none'
}
cancelBtn.onclick = cancel
document.addEventListener('keydown', event => {
    if (event.key == 'Escape') cancel()
})
