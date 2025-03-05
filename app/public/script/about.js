const transitions = document.getElementsByClassName('off-screen')

const options = {
    root: null,
    rootMargin: '0px',
    threshold: 0
}

for (const element of transitions) {
    const observer = new IntersectionObserver((entries, observer) => {
        if (entries[0].isIntersecting) {
            element.classList.replace('off-screen', 'on-screen')
        }
        else {
            element.classList.replace('on-screen', 'off-screen')
        }
    }, options)
    observer.observe(element)
}

const aboutCard = document.getElementById('about-card')
enableFlip(aboutCard)
