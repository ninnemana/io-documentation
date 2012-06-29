/* 
  *
  * Example file for the Go Currency talk
  * Presenter: Rob Pike
  *
*/

import(
  "fmt"
)

  func main(){

  	boring("boring!")

  	// Run as a Go Routing
  	go boring("bording!")
  }

  func boring(msg string){
  	for i = 0; i++{
  		fmt.Println(msg, i)
  		time.Sleep(time.Second)
  	}
  }

// Channel

	var c chan int
	c = make(chan int)
	// or
	c := make(chan int)
	// Set
	c <- 1
	// Get
	value = <- c
