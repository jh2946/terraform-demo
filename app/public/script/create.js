const form = document.getElementById('form')
const title = document.getElementById('title')
title.focus()

title.addEventListener('keydown', event => {
    if (event.key == 'Enter') form.submit()
})

addEventListener('keydown', event => {
    if (event.key == 'Enter' && event.ctrlKey) form.submit()
})
